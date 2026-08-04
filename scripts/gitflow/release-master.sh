#!/usr/bin/env bash
set -euo pipefail

echo "=== Publicando cambios de 'develop' a 'master' (Release) ==="

git checkout master
git pull origin master
git merge --no-ff develop -m "Release: Merge 'develop' into master"
git push origin master

git checkout develop
echo "✅ 'develop' sincronizado y publicado con éxito en 'master'."
