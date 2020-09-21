/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATION_H_

#include <memory>
#include <vector>

#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/model/field_mask.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/precondition.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

namespace firebase {
namespace firestore {
namespace model {

/**
 * Represents a Mutation of a document. Different subclasses of Mutation will
 * perform different kinds of changes to a base document. For example, a
 * SetMutation replaces the value of a document and a DeleteMutation deletes a
 * document.
 *
 * In addition to the value of the document mutations also operate on the
 * version. For local mutations (mutations that haven't been committed yet), we
 * preserve the existing version for Set, Patch, and Transform mutations. For
 * local deletes, we reset the version to 0.
 *
 * Here's the expected transition table.
 *
 * MUTATION           APPLIED TO      RESULTS IN
 * SetMutation        Document(v3)    Document(v3)
 * SetMutation        NoDocument(v3)  Document(v0)
 * SetMutation        null            Document(v0)
 * PatchMutation      Document(v3)    Document(v3)
 * PatchMutation      NoDocument(v3)  NoDocument(v3)
 * PatchMutation      null            null
 * TransformMutation  Document(v3)    Document(v3)
 * TransformMutation  NoDocument(v3)  NoDocument(v3)
 * TransformMutation  null            null
 * DeleteMutation     Document(v3)    NoDocument(v0)
 * DeleteMutation     NoDocument(v3)  NoDocument(v0)
 * DeleteMutation     null            NoDocument(v0)
 *
 * For acknowledged mutations, we use the updateTime of the WriteResponse as the
 * resulting version for Set, Patch, and Transform mutations. As deletes have no
 * explicit update time, we use the commitTime of the WriteResponse for
 * acknowledged deletes.
 *
 * If a mutation is acknowledged by the backend but fails the precondition check
 * locally, we return an `UnknownDocument` and rely on Watch to send us the
 * updated version.
 *
 * Note that TransformMutations don't create Documents (in the case of being
 * applied to a NoDocument), even though they would on the backend. This is
 * because the client always combines the TransformMutation with a SetMutation
 * or PatchMutation and we only want to apply the transform if the prior
 * mutation resulted in a Document (always true for a SetMutation, but not
 * necessarily for an PatchMutation).
 */
class Mutation {
 public:
  enum class Type {
    kSet,
    kPatch,
    kTransform,
    kDelete,
  };

  virtual ~Mutation() {
  }

  virtual Type type() const = 0;

  const DocumentKey& key() const {
    return key_;
  }
  const Precondition& precondition() const {
    return precondition_;
  }

  // TODO(rsgowman): ApplyToRemoteDocument()

  /**
   * Applies this mutation to the given MaybeDocument for the purposes of
   * computing the new local view of a document. Both the input and returned
   * documents can be nullptr.
   *
   * @param maybe_doc The document to mutate. The input document can be nullptr
   *     if the client has no knowledge of the pre-mutation state of the
   *     document.
   * @param base_doc The state of the document prior to this mutation batch. The
   *     input document can be nullptr if the client has no knowledge of the
   *     pre-mutation state of the document.
   * @param local_write_time A timestamp indicating the local write time of the
   *     batch this mutation is a part of.
   * @return The mutated document. The returned document may be nullptr, but
   *     only if maybe_doc was nullptr and the mutation would not create a new
   *     document.
   */
  virtual std::shared_ptr<const MaybeDocument> ApplyToLocalView(
      const std::shared_ptr<const MaybeDocument>& maybe_doc,
      const MaybeDocument* base_doc,
      const Timestamp& local_write_time) const = 0;

  friend bool operator==(const Mutation& lhs, const Mutation& rhs) {
    return lhs.IsEqualTo(rhs);
  }

 protected:
  Mutation(DocumentKey&& key, Precondition&& precondition);

  /**
   * Derived classes should override this method to implement equality. However,
   * derived classes should also call this method as part of their equality
   * checks to ensure the data managed by the base class is equal.
   *
   * This method explicitly checks the type() to ensure they're equal, implying
   * that derived classes can assume the types are the same in their IsEqualTo
   * method, assuming they call this parent IsEqualTo first.
   */
  virtual bool IsEqualTo(const Mutation& other) const;

  void VerifyKeyMatches(const MaybeDocument* maybe_doc) const;

  static SnapshotVersion GetPostMutationVersion(const MaybeDocument* maybe_doc);

 private:
  const DocumentKey key_;
  const Precondition precondition_;
};

inline bool operator!=(const Mutation& lhs, const Mutation& rhs) {
  return !(lhs == rhs);
}

/**
 * A mutation that creates or replaces the document at the given key with the
 * object value contents.
 */
class SetMutation : public Mutation {
 public:
  SetMutation(DocumentKey&& key,
              FieldValue&& value,
              Precondition&& precondition);

  Type type() const override {
    return Type::kSet;
  }

  const FieldValue& value() const {
    return value_;
  }

  // TODO(rsgowman): ApplyToRemoteDocument()

  std::shared_ptr<const MaybeDocument> ApplyToLocalView(
      const std::shared_ptr<const MaybeDocument>& maybe_doc,
      const MaybeDocument* base_doc,
      const Timestamp& local_write_time) const override;

 protected:
  bool IsEqualTo(const Mutation& other) const override;

 private:
  const FieldValue value_;
};

/**
 * A mutation that modifies fields of the document at the given key with the
 * given values. The values are applied through a field mask:
 *
 * - When a field is in both the mask and the values, the corresponding field is
 *   updated.
 * - When a field is in neither the mask nor the values, the corresponding field
 *   is unmodified.
 * - When a field is in the mask but not in the values, the corresponding field
 *   is deleted.
 * - When a field is not in the mask but is in the values, the values map is
 *   ignored.
 */
class PatchMutation : public Mutation {
 public:
  PatchMutation(DocumentKey&& key,
                FieldValue&& value,
                FieldMask&& mask,
                Precondition&& precondition);

  Type type() const override {
    return Type::kPatch;
  }

  const FieldValue& value() const {
    return value_;
  }
  const FieldMask& mask() const {
    return mask_;
  }

  // TODO(rsgowman): ApplyToRemoteDocument()

  std::shared_ptr<const MaybeDocument> ApplyToLocalView(
      const std::shared_ptr<const MaybeDocument>& maybe_doc,
      const MaybeDocument* base_doc,
      const Timestamp& local_write_time) const override;

 protected:
  bool IsEqualTo(const Mutation& other) const override;

 private:
  FieldValue PatchDocument(const MaybeDocument* maybe_doc) const;
  FieldValue PatchObject(FieldValue obj) const;

  const FieldValue value_;
  const FieldMask mask_;
};

/** Represents a Delete operation. */
class DeleteMutation : public Mutation {
 public:
  DeleteMutation(DocumentKey&& key, Precondition&& precondition);

  Type type() const override {
    return Type::kDelete;
  }

  // TODO(rsgowman): ApplyToRemoteDocument()

  std::shared_ptr<const MaybeDocument> ApplyToLocalView(
      const std::shared_ptr<const MaybeDocument>& maybe_doc,
      const MaybeDocument* base_doc,
      const Timestamp& local_write_time) const override;

  // IsEqualTo explicitly not overridden. DeleteMutation has nothing further to
  // add to the definition of equality.
};

/**
 * A batch of mutations that will be sent as one unit to the backend. Batches
 * can be marked as a tombstone if the mutation queue does not remove them
 * immediately. When a batch is a tombstone it has no mutations.
 */
class MutationBatch {
 public:
  /**
   * @param mutations Pointers to the mutations to be applied.
   */
  MutationBatch(int batch_id,
                Timestamp local_write_time,
                std::vector<std::shared_ptr<Mutation>> mutations);

  friend bool operator==(const MutationBatch& lhs, const MutationBatch& rhs);

  int batch_id() const {
    return batch_id_;
  }
  Timestamp local_write_time() const {
    return local_write_time_;
  }
  const std::vector<std::shared_ptr<Mutation>>& mutations() const {
    return mutations_;
  }

 private:
  const int batch_id_;
  const Timestamp local_write_time_;
  const std::vector<std::shared_ptr<Mutation>> mutations_;
};

bool operator==(const MutationBatch& lhs, const MutationBatch& rhs);

inline bool operator!=(const MutationBatch& lhs, const MutationBatch& rhs) {
  return !(lhs == rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_MODEL_MUTATION_H_
