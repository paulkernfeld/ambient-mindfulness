#!/bin/bash
# Make this repo public (write operation — enables free macOS CI minutes)
set -e
echo "Making repo public..."
gh repo edit --visibility public
echo "Done. Repo is now public."
echo "macOS CI runners should now be available."
