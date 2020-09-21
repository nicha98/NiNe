#!/bin/bash

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Prepares a host for running check.sh

set -euo pipefail

export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1

brew install clang-format
brew install swiftformat

clang-format -version
swiftformat -version

pip install flake8
pip install six

# Using actions/checkout@v2 creates a shallow clone that's missing the master
# branch. If it's not present, add it.
if ! git rev-parse origin/master >& /dev/null; then
  git remote set-branches --add origin master
  git fetch origin
fi
