### Helper functions

# Determine if any of the files were changed or deleted.
# Taken from samdmarshall/danger
def didModify(files_array)
  files_array.each do |file_name|
    if git.modified_files.include?(file_name) ||
       git.deleted_files.include?(file_name)
      return true
    end
  end
  return false
end

# Determine if there are changes in files matching any of the
# path patterns provided.
def hasChangesIn(paths)
  path_array = Array(paths)
  path_array.each do |dir|
    if !git.modified_files.grep(/#{dir}/).empty?
      return true
    end
  end
  return false
end

# Adds the provided labels to the current PR.
def addLabels(label_array)
  issue_number = github.pr_json["number"]
  repo_name = "firebase/firebase-ios-sdk"
  github.api.add_labels_to_an_issue(repo_name, issue_number, label_array)
end

# Returns a list of all labels for a given PR. PRs that touch
# multiple directories may have multiple labels.
def labelsForModifiedFiles()
  labels = []
  labels.push("api: abtesting") if @has_abtesting_changes
  labels.push("api: auth") if @has_auth_changes
  labels.push("api: core") if @has_core_changes
  labels.push("api: crashlytics") if @has_crashlytics_changes
  labels.push("api: database") if @has_database_changes
  labels.push("api: dynamiclinks") if @has_dynamiclinks_changes
  labels.push("api: firestore") if @has_firestore_changes
  labels.push("api: functions") if @has_functions_changes
  labels.push("api: inappmessaging") if @has_inappmessaging_changes
  labels.push("api: installations") if @has_installations_changes
  labels.push("api: instanceid") if @has_instanceid_changes
  labels.push("api: messaging") if @has_messaging_changes
  labels.push("api: remoteconfig") if @has_remoteconfig_changes
  labels.push("api: storage") if @has_storage_changes
  labels.push("GoogleDataTransport") if @has_gdt_changes
  labels.push("GoogleUtilities") if @has_googleutilities_changes
  labels.push("zip-builder") if @has_zipbuilder_changes
  labels.push("public-api-change") if @has_api_changes
  return labels
end

### Definitions

# Label for any change that shouldn't have an accompanying CHANGELOG entry,
# including all changes that do not affect the compiled binary (i.e. script
# changes, test-only changes)
declared_trivial = github.pr_body.include? "#no-changelog"

# Whether or not there are pending changes to any changelog file.
has_changelog_changes = hasChangesIn(["CHANGELOG"])

# Whether or not the LICENSE file has been modified or deleted.
has_license_changes = didModify(["LICENSE"])

## Product directories
@has_abtesting_changes = hasChangesIn("FirebaseABTesting/")
@has_abtesting_api_changes = hasChangesIn("FirebaseABTesting/Sources/Public/")
@has_auth_changes = hasChangesIn("FirebaseAuth")
@has_auth_api_changes = hasChangesIn("FirebaseAuth/Sources/Public/")
@has_core_changes = hasChangesIn([
  "FirebaseCore/",
  "Firebase/CoreDiagnostics/",
  "CoreOnly/"])
@has_core_api_changes = hasChangesIn("FirebaseCore/Sources/Public/")
@has_crashlytics_changes = hasChangesIn("Crashlytics/")
@has_crashlytics_api_changes = hasChangesIn("Crashlytics/Crashlytics/Public/")
@has_database_changes = hasChangesIn("Firebase/Database/")
@has_database_api_changes = hasChangesIn("Firebase/Database/Public/")
@has_dynamiclinks_changes = hasChangesIn("FirebaseDynamicLinks/")
@has_dynamiclinks_api_changes = hasChangesIn("FirebaseDynamicLinks/Sources/Public/")
@has_firestore_changes = hasChangesIn("Firestore/")
@has_firestore_api_changes = hasChangesIn("Firestore/Source/Public/")
@has_functions_changes = hasChangesIn("Functions/")
@has_functions_api_changes = hasChangesIn("Functions/FirebaseFunctions/Public/")
@has_inappmessaging_changes = hasChangesIn(["FirebaseInAppMessaging/"])
@has_inappmessaging_api_changes = hasChangesIn(["FirebaseInAppMessaging/Sources/Public/"])
@has_installations_changes = hasChangesIn("FirebaseInstallations/Source/")
@has_installations_api_changes = hasChangesIn("FirebaseInstallations/Source/Library/Public/")
@has_instanceid_changes = hasChangesIn("Firebase/InstanceID/")
@has_instanceid_api_changes = hasChangesIn("Firebase/InstanceID/Public/")
@has_messaging_changes = hasChangesIn("Firebase/Messaging/")
@has_messaging_api_changes = hasChangesIn("Firebase/Messaging/Public/")
@has_remoteconfig_changes = hasChangesIn("FirebaseRemoteConfig/")
@has_remoteconfig_api_changes = hasChangesIn("FirebaseRemoteConfig/Sources/Public/")
@has_storage_changes = hasChangesIn("FirebaseStorage/")
@has_storage_api_changes = hasChangesIn("FirebaseStorage/Sources/Public/")

@has_gdt_changes = hasChangesIn(["GoogleDataTransport/", "GoogleDataTransportCCTSupport/"])
@has_gdt_api_changes = hasChangesIn("GoogleDataTransport/GDTCORLibrary/Public")
@has_googleutilities_changes = hasChangesIn("GoogleUtilities/")
@has_zipbuilder_changes = hasChangesIn("ZipBuilder/")

# Convenient flag for all API changes.
@has_api_changes = @has_abtesting_api_changes ||
                     @has_auth_api_changes ||
                     @has_core_api_changes ||
                     @has_crashlytics_api_changes ||
                     @has_database_api_changes ||
                     @has_dynamiclinks_api_changes ||
                     @has_firestore_api_changes ||
                     @has_functions_api_changes ||
                     @has_inappmessaging_api_changes ||
                     @has_installations_api_changes ||
                     @has_instanceid_api_changes ||
                     @has_messaging_api_changes ||
                     @has_remoteconfig_api_changes ||
                     @has_storage_api_changes ||
                     @has_gdt_api_changes

# A FileList containing ObjC, ObjC++ or C++ changes.
sdk_changes = (git.modified_files +
               git.added_files +
               git.deleted_files).select do |line|
  line.end_with?(".h") ||
    line.end_with?(".m") ||
    line.end_with?(".mm") ||
    line.end_with?(".cc") ||
    line.end_with?(".swift")
end

# Whether or not the PR has modified SDK source files.
has_sdk_changes = sdk_changes.empty?

### Actions

# Warn if a changelog is left out on a non-trivial PR that has modified
# SDK source files (podspec, markdown, etc changes are excluded).
if has_sdk_changes
  if !has_changelog_changes && !declared_trivial
    warning = "Did you forget to add a changelog entry? (Add #no-changelog"\
      " to the PR description to silence this warning.)"
    warn(warning)
  end
end

# Error on license edits
fail("LICENSE changes are explicitly disallowed.") if has_license_changes

# Label PRs based on diff files
suggested_labels = labelsForModifiedFiles()
if !suggested_labels.empty?
  addLabels(suggested_labels)
end
