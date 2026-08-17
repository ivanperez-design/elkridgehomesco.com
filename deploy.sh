#!/bin/bash
# ERH site deploy — GitHub Pages serves from gh-pages, NOT main.
# A push to main alone does NOT deploy (learned the hard way 2026-08-17).
# Usage: ./deploy.sh  (run from repo root, after committing to main)
set -euo pipefail
git push origin main
git checkout gh-pages
git merge main -m "deploy: merge main $(git log main -1 --format=%h)"
git push origin gh-pages
git checkout main
echo "Deployed. Verifying live (Pages builds take 1-10 min)..."
sleep 60
if curl -s "https://elkridgehomesco.com/?v=$RANDOM" | grep -q "$(git log main -1 --format=%h)" ; then
  echo "NOTE: commit-hash check not embedded in pages; run a content check manually:"
fi
curl -sI https://elkridgehomesco.com/ | grep -i last-modified
echo "Compare last-modified above to now. If stale, wait and re-check."
