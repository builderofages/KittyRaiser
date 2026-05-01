# Push to GitHub — Run This Block in Mac Terminal

The repo at https://github.com/builderofages/KittyRaiser already has the v1.1 commit. This session staged v1.2 (lobby, modern HUD, NYC city, mini-games, NPCs, districts, sound) but the sandbox can't finalize the commit due to permission issues with `.git/objects`.

## Open Terminal on your Mac (Cmd+Space → "Terminal")

Then paste this entire block:

```bash
cd "/Users/alexandermills/Library/Application Support/Claude/local-agent-mode-sessions/d150439c-47ce-4bcd-ada3-684a6fe12845/b5e612e6-a4e6-4a62-a734-f72baa3d9e43/local_6cdcb0f7-9dc9-4d51-add3-619923558438/outputs/KittyRaiser"

# Clean leftover sandbox lock files
find .git -name "*.lock" -delete 2>/dev/null
find .git/objects -name "tmp_obj_*" -delete 2>/dev/null

# Stage everything new from this session
git add -A

# Commit
git -c user.name="Alexander Mills" -c user.email="trainyouragent@gmail.com" \
    commit -m "feat: v1.2 — lobby, modern HUD, NYC city, mini-games, NPCs, districts, sound, audit"

# Wire remote and push
git remote remove origin 2>/dev/null
git remote add origin https://github.com/builderofages/KittyRaiser.git
git push -u origin main
```

## If git asks for credentials

- Username: `builderofages`
- Password: a **GitHub Personal Access Token** (not your account password)
  - Get one at https://github.com/settings/tokens/new
  - Scope: check `repo`
  - Copy and paste as the password
  - macOS will offer to save in Keychain — say yes

## After it pushes

- Visit https://github.com/builderofages/KittyRaiser to verify
- The `deploys/` folder will show all 10 PASTE scripts
- The `src/` folder has the Rojo-aware sources

## Move repo to permanent home (optional)

```bash
mv "/Users/alexandermills/Library/Application Support/Claude/local-agent-mode-sessions/d150439c-47ce-4bcd-ada3-684a6fe12845/b5e612e6-a4e6-4a62-a734-f72baa3d9e43/local_6cdcb0f7-9dc9-4d51-add3-619923558438/outputs/KittyRaiser" ~/KittyRaiser
cd ~/KittyRaiser
```

Future commits/pushes from `~/KittyRaiser` will be much faster.
