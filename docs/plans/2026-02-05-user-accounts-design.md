# User Accounts & Permissions Design

**Date:** 2026-02-05
**Status:** Draft
**Target Version:** v0.22

## Overview

Add user authentication and permission-based access control to DigiLab. This enables multi-region support by allowing Scene Admins to manage their own region's data while preventing unauthorized edits to other regions.

### Goals (Priority Order)

1. **Enable multi-region administration** - Scene Admins manage their own scene's data
2. **Maintain viewer accessibility** - No login required to view data
3. **Community integration** - Use Discord (where TCG community already exists)
4. **Audit trail** - Track who submitted/edited what
5. **Scalable permissions** - Foundation for future permission tiers if needed

### Non-Goals

- User profiles/social features (players are separate from users)
- Self-registration for admin access (admin approval required)
- Email/password authentication (Discord only for simplicity)

---

## Authentication Method: Discord OAuth

### Why Discord?

| Factor | Benefit |
|--------|---------|
| Community presence | Digimon TCG community is heavily Discord-based |
| No new accounts | Players already have Discord accounts |
| Free | No cost, no rate limits at our scale |
| Trusted | Users recognize Discord login, not a random site |
| Future integration | Enables Discord bot for result reporting later |

### OAuth Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│ User Experience                                                       │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  1. User clicks "Login with Discord" button in header                │
│                                                                       │
│  2. Browser redirects to Discord:                                    │
│     https://discord.com/oauth2/authorize?                            │
│       client_id=YOUR_APP_ID&                                         │
│       redirect_uri=https://digilab.cards/auth/callback&              │
│       response_type=code&                                            │
│       scope=identify                                                 │
│                                                                       │
│  3. Discord shows authorization screen:                              │
│     ┌─────────────────────────────────────────┐                      │
│     │ DigiLab wants to access your account    │                      │
│     │                                         │                      │
│     │ This will allow DigiLab to:             │                      │
│     │ • See your username and avatar          │                      │
│     │                                         │                      │
│     │ [Authorize]  [Cancel]                   │                      │
│     └─────────────────────────────────────────┘                      │
│                                                                       │
│  4. User clicks Authorize                                            │
│                                                                       │
│  5. Discord redirects back to DigiLab with code:                     │
│     https://digilab.cards/auth/callback?code=abc123                  │
│                                                                       │
│  6. DigiLab server exchanges code for access token (server-side)     │
│                                                                       │
│  7. DigiLab fetches user info from Discord API                       │
│                                                                       │
│  8. DigiLab creates/updates user record, sets session cookie         │
│                                                                       │
│  9. User sees: "Welcome, PlayerName!" with their avatar              │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

### Discord Developer Setup

1. Create application at https://discord.com/developers/applications
2. Add OAuth2 redirect URL: `https://digilab.cards/auth/callback`
3. Copy Client ID and Client Secret
4. Store as environment variables (never commit to git)

### Environment Variables

```
# .env (add to .env.example)
DISCORD_CLIENT_ID=your_client_id_here
DISCORD_CLIENT_SECRET=your_client_secret_here
DISCORD_REDIRECT_URI=https://digilab.cards/auth/callback
```

---

## Permission Levels

### Three-Tier Model

| Level | Login Required | Scope | Capabilities |
|-------|----------------|-------|--------------|
| **Viewer** | No | Global | View all data, use filters, view modals |
| **Scene Admin** | Yes | 1 Scene | Submit results, edit data for their scene |
| **Super Admin** | Yes | Global | Everything, plus manage users and scenes |

### Viewer (Default)

- No login required
- Full read access to all public data
- Scene preference stored in localStorage
- Can use all filters, view all modals
- Cannot submit or edit any data

### Scene Admin

- Must log in with Discord
- Assigned to one specific scene (e.g., "DFW Digimon")
- Can do everything for their scene:
  - Submit tournament results (screenshot or manual)
  - Edit tournaments, players, results
  - Approve store/deck requests for their scene
  - Add/edit stores in their scene
- Cannot:
  - Edit data from other scenes
  - Manage users
  - Create/edit scenes
  - Access system settings

### Super Admin

- Must log in with Discord
- Full access to everything:
  - All Scene Admin capabilities for all scenes
  - Create/edit/delete scenes
  - Manage users (promote, demote, assign scenes)
  - Generate admin invite links
  - Manage global data (deck archetypes, formats)
  - Access system settings and audit logs

---

## Database Schema

### New: `users` Table

```sql
CREATE TABLE users (
  user_id INTEGER PRIMARY KEY,
  discord_id TEXT UNIQUE NOT NULL,
  discord_username TEXT NOT NULL,
  discord_avatar TEXT,
  role TEXT NOT NULL DEFAULT 'viewer',  -- 'viewer', 'scene_admin', 'super_admin'
  scene_id INTEGER REFERENCES scenes(scene_id),  -- NULL for super_admin
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_login_at TIMESTAMP
);

-- Index for fast Discord ID lookups
CREATE INDEX idx_users_discord_id ON users(discord_id);
```

### New: `admin_invites` Table

```sql
CREATE TABLE admin_invites (
  invite_id INTEGER PRIMARY KEY,
  code TEXT UNIQUE NOT NULL,
  role TEXT NOT NULL,  -- 'scene_admin' or 'super_admin'
  scene_id INTEGER REFERENCES scenes(scene_id),  -- NULL for super_admin
  created_by INTEGER REFERENCES users(user_id),
  used_by INTEGER REFERENCES users(user_id),
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  used_at TIMESTAMP
);
```

### New: `user_sessions` Table

```sql
CREATE TABLE user_sessions (
  session_id TEXT PRIMARY KEY,
  user_id INTEGER REFERENCES users(user_id),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP NOT NULL,
  ip_address TEXT,
  user_agent TEXT
);

-- Clean up expired sessions periodically
CREATE INDEX idx_sessions_expires ON user_sessions(expires_at);
```

### Modified: Add `submitted_by` to Existing Tables

```sql
-- Track who submitted tournament results
ALTER TABLE tournaments ADD COLUMN submitted_by INTEGER REFERENCES users(user_id);

-- Track who submitted store/deck requests
ALTER TABLE store_requests ADD COLUMN submitted_by INTEGER REFERENCES users(user_id);
ALTER TABLE deck_requests ADD COLUMN submitted_by INTEGER REFERENCES users(user_id);
```

---

## Admin Promotion Workflow

### Method 1: Invite Links

Super Admin generates a one-time invite link:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Super Admin Panel: Create Invite                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ Create Admin Invite                                                  │
│                                                                      │
│ Role: [Scene Admin ▼]                                                │
│ Scene: [Houston Tamers ▼]   (required for Scene Admin)               │
│ Expires: [7 days ▼]                                                  │
│                                                                      │
│ [Generate Link]                                                      │
│                                                                      │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ https://digilab.cards/?invite=xK9mP2qR                           │ │
│ │                                                       [Copy]     │ │
│ └──────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│ Share this link with the person you want to invite.                  │
│ They'll become a Houston Tamers Scene Admin when they log in.        │
│                                                                      │
│ Active Invites:                                                      │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ Code     │ Role        │ Scene    │ Expires    │ Status │ Action │ │
│ ├──────────────────────────────────────────────────────────────────┤ │
│ │ xK9mP2qR │ scene_admin │ Houston  │ Feb 12     │ Active │ [Revoke]│ │
│ │ aB3cD4eF │ scene_admin │ Austin   │ Feb 10     │ Used   │ -      │ │
│ └──────────────────────────────────────────────────────────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Invite link flow:**
1. Recipient clicks link
2. App detects `?invite=` parameter
3. If not logged in, prompts Discord login
4. After login, checks invite validity (not expired, not used)
5. Upgrades user role, assigns scene
6. Marks invite as used
7. Shows success message: "You're now a Houston Tamers Scene Admin!"

### Method 2: Direct Promotion

For users who have already logged in:

```
┌─────────────────────────────────────────────────────────────────────┐
│ Super Admin Panel: Manage Users                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ Search: [atomshell              ] [Search]                           │
│                                                                      │
│ ┌──────────────────────────────────────────────────────────────────┐ │
│ │ User          │ Role        │ Scene    │ Last Login │ Actions    │ │
│ ├──────────────────────────────────────────────────────────────────┤ │
│ │ atomshell     │ viewer      │ -        │ Today      │ [Promote]  │ │
│ │ happycat      │ scene_admin │ DFW      │ Yesterday  │ [Edit]     │ │
│ │ digiking      │ scene_admin │ Houston  │ 3 days ago │ [Edit]     │ │
│ │ admin_mike    │ super_admin │ -        │ Today      │ [Edit]     │ │
│ └──────────────────────────────────────────────────────────────────┘ │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

**Promote modal:**
```
┌─────────────────────────────────────────┐
│ Promote atomshell                       │
├─────────────────────────────────────────┤
│                                         │
│ New Role:                               │
│ ○ Scene Admin                           │
│ ○ Super Admin                           │
│                                         │
│ Assign to Scene: [DFW Digimon ▼]        │
│ (required for Scene Admin)              │
│                                         │
│ [Confirm Promotion] [Cancel]            │
│                                         │
└─────────────────────────────────────────┘
```

### Bootstrap: First Super Admin

The first Super Admin is seeded directly in the database during deployment:

```sql
-- Run once during initial setup
-- Replace with your actual Discord ID
INSERT INTO users (discord_id, discord_username, role)
VALUES ('YOUR_DISCORD_ID', 'YourUsername', 'super_admin');
```

To get your Discord ID:
1. Enable Developer Mode in Discord (Settings → Advanced → Developer Mode)
2. Right-click your username → Copy User ID

---

## Session Management

### How Sessions Work

1. After Discord OAuth, server generates random session ID
2. Session ID stored in `user_sessions` table
3. Session ID sent to browser as secure HTTP-only cookie
4. On each request, server looks up session, gets user info
5. Sessions expire after 30 days (configurable)

### Session Cookie

```r
# Set session cookie after successful login
session$sendCustomMessage("setSessionCookie", list(
  name = "digilab_session",
  value = session_id,
  expires = 30,  # days
  secure = TRUE,
  httpOnly = TRUE,
  sameSite = "Lax"
))
```

### Logout

1. User clicks "Logout"
2. Server deletes session from `user_sessions` table
3. Browser cookie cleared
4. User becomes Viewer again

---

## UI Changes

### Header (Logged Out)

```
┌─────────────────────────────────────────────────────────────────────┐
│ [DigiLab Logo]  DigiLab                    [Login with Discord]     │
└─────────────────────────────────────────────────────────────────────┘
```

### Header (Logged In)

```
┌─────────────────────────────────────────────────────────────────────┐
│ [DigiLab Logo]  DigiLab              [Avatar] atomshell ▼           │
│                                      ├─────────────────────┤        │
│                                      │ Scene: DFW Digimon  │        │
│                                      │ Role: Scene Admin   │        │
│                                      │ ─────────────────── │        │
│                                      │ [Logout]            │        │
│                                      └─────────────────────┘        │
└─────────────────────────────────────────────────────────────────────┘
```

### Sidebar (Permission-Scoped)

```
Viewer:                    Scene Admin:              Super Admin:
┌───────────────────┐     ┌───────────────────┐     ┌───────────────────┐
│ Overview          │     │ Overview          │     │ Overview          │
│ Players           │     │ Players           │     │ Players           │
│ Meta              │     │ Meta              │     │ Meta              │
│ Tournaments       │     │ Tournaments       │     │ Tournaments       │
│ Stores            │     │ Stores            │     │ Stores            │
│ Submit Results    │     │ Submit Results    │     │ Submit Results    │
│                   │     │ ───────────────── │     │ ───────────────── │
│                   │     │ ▼ DFW Admin       │     │ ▼ DFW Admin       │
│                   │     │   Enter Results   │     │   Enter Results   │
│                   │     │   Edit Tournaments│     │   Edit Tournaments│
│                   │     │   Edit Stores     │     │   Edit Stores     │
│                   │     │   Edit Players    │     │   Edit Players    │
│                   │     │   Review Requests │     │   Review Requests │
│                   │     │                   │     │ ───────────────── │
│                   │     │                   │     │ ▼ System          │
│                   │     │                   │     │   Manage Scenes   │
│                   │     │                   │     │   Manage Users    │
│                   │     │                   │     │   Manage Decks    │
│                   │     │                   │     │   Manage Formats  │
└───────────────────┘     └───────────────────┘     └───────────────────┘
```

### Implementation

```r
# In app.R or shared-server.R
output$sidebar_ui <- renderUI({
  user <- rv$current_user  # NULL if not logged in

  public_tabs <- list(
    nav_panel("Overview", dashboard_ui("dashboard")),
    nav_panel("Players", players_ui("players")),
    nav_panel("Meta", meta_ui("meta")),
    nav_panel("Tournaments", tournaments_ui("tournaments")),
    nav_panel("Stores", stores_ui("stores")),
    nav_panel("Submit Results", submit_ui("submit"))
  )

  scene_admin_tabs <- if (!is.null(user) && user$role %in% c("scene_admin", "super_admin")) {
    scene_name <- get_scene_name(user$scene_id)
    list(
      nav_spacer(),
      nav_item(tags$strong(paste0(scene_name, " Admin"))),
      nav_panel("Enter Results", admin_results_ui("admin_results")),
      nav_panel("Edit Tournaments", admin_tournaments_ui("admin_tournaments")),
      nav_panel("Edit Stores", admin_stores_ui("admin_stores")),
      nav_panel("Edit Players", admin_players_ui("admin_players")),
      nav_panel("Review Requests", admin_requests_ui("admin_requests"))
    )
  }

  super_admin_tabs <- if (!is.null(user) && user$role == "super_admin") {
    list(
      nav_spacer(),
      nav_item(tags$strong("System")),
      nav_panel("Manage Scenes", admin_scenes_ui("admin_scenes")),
      nav_panel("Manage Users", admin_users_ui("admin_users")),
      nav_panel("Manage Decks", admin_decks_ui("admin_decks")),
      nav_panel("Manage Formats", admin_formats_ui("admin_formats"))
    )
  }

  do.call(navset_pill_list, c(public_tabs, scene_admin_tabs, super_admin_tabs))
})
```

---

## localStorage for Viewers

Viewers (not logged in) can still have preferences saved locally:

| Preference | Storage | Syncs Across Devices? |
|------------|---------|----------------------|
| Selected scene | localStorage | No |
| Dark mode | localStorage | No |
| First visit flag | localStorage | No |
| Table page sizes | localStorage | No |

```javascript
// Save scene preference
localStorage.setItem('digilab_scene', 'dfw');

// Read on page load
const savedScene = localStorage.getItem('digilab_scene');
Shiny.setInputValue('saved_scene_preference', savedScene);
```

Logged-in users could optionally have preferences stored in the database for cross-device sync (future enhancement).

---

## Technical Implementation

### New Files

```
R/
├── auth.R                    # Discord OAuth helpers
│
server/
├── auth-server.R             # Login/logout handlers, session management
├── admin-users-server.R      # User management (Super Admin)
├── admin-scenes-server.R     # Scene management (Super Admin)
│
views/
├── admin-users-ui.R          # User management UI
├── admin-scenes-ui.R         # Scene management UI
│
www/
├── auth.js                   # Session cookie handling
```

### auth.R (~150 lines)

```r
library(httr2)

# Discord OAuth endpoints
DISCORD_AUTH_URL <- "https://discord.com/oauth2/authorize"
DISCORD_TOKEN_URL <- "https://discord.com/api/oauth2/token"
DISCORD_USER_URL <- "https://discord.com/api/users/@me"

#' Generate Discord OAuth URL
discord_auth_url <- function(state = NULL) {
  params <- list(
    client_id = Sys.getenv("DISCORD_CLIENT_ID"),
    redirect_uri = Sys.getenv("DISCORD_REDIRECT_URI"),
    response_type = "code",
    scope = "identify"
  )
  if (!is.null(state)) params$state <- state

  paste0(DISCORD_AUTH_URL, "?", paste(names(params), params, sep = "=", collapse = "&"))
}

#' Exchange authorization code for access token
discord_exchange_code <- function(code) {
  response <- request(DISCORD_TOKEN_URL) |>
    req_body_form(
      client_id = Sys.getenv("DISCORD_CLIENT_ID"),
      client_secret = Sys.getenv("DISCORD_CLIENT_SECRET"),
      grant_type = "authorization_code",
      code = code,
      redirect_uri = Sys.getenv("DISCORD_REDIRECT_URI")
    ) |>
    req_perform() |>
    resp_body_json()

  response$access_token
}

#' Fetch user info from Discord
discord_get_user <- function(access_token) {
  response <- request(DISCORD_USER_URL) |>
    req_auth_bearer_token(access_token) |>
    req_perform() |>
    resp_body_json()

  list(
    discord_id = response$id,
    username = paste0(response$username, "#", response$discriminator),
    avatar = response$avatar
  )
}

#' Generate session ID
generate_session_id <- function() {
  paste0(sample(c(letters, LETTERS, 0:9), 64, replace = TRUE), collapse = "")
}

#' Create or update user record
upsert_user <- function(db, discord_user) {
  existing <- dbGetQuery(db,
    "SELECT * FROM users WHERE discord_id = ?",
    params = list(discord_user$discord_id)
  )

  if (nrow(existing) == 0) {
    # New user - create as viewer
    dbExecute(db,
      "INSERT INTO users (discord_id, discord_username, discord_avatar, role)
       VALUES (?, ?, ?, 'viewer')",
      params = list(
        discord_user$discord_id,
        discord_user$username,
        discord_user$avatar
      )
    )
  } else {
    # Existing user - update last login
    dbExecute(db,
      "UPDATE users SET discord_username = ?, discord_avatar = ?, last_login_at = CURRENT_TIMESTAMP
       WHERE discord_id = ?",
      params = list(
        discord_user$username,
        discord_user$avatar,
        discord_user$discord_id
      )
    )
  }

  # Return full user record
  dbGetQuery(db, "SELECT * FROM users WHERE discord_id = ?",
             params = list(discord_user$discord_id))
}
```

### Permission Checking

```r
#' Check if user can edit a specific scene
can_edit_scene <- function(user, scene_id) {
  if (is.null(user)) return(FALSE)
  if (user$role == "super_admin") return(TRUE)
  if (user$role == "scene_admin" && user$scene_id == scene_id) return(TRUE)
  FALSE
}

#' Check if user can manage users
can_manage_users <- function(user) {
  !is.null(user) && user$role == "super_admin"
}

#' Require permission or show error
require_permission <- function(user, permission_check, error_message = "Permission denied") {
  if (!permission_check) {
    showNotification(error_message, type = "error")
    return(FALSE)
  }
  TRUE
}
```

---

## Security Considerations

### Session Security

- Session IDs are 64 random characters (cryptographically secure)
- Cookies are `HttpOnly` (no JavaScript access)
- Cookies are `Secure` (HTTPS only)
- Cookies are `SameSite=Lax` (CSRF protection)
- Sessions expire after 30 days
- Logout invalidates session server-side

### OAuth Security

- Client secret never exposed to browser
- State parameter prevents CSRF attacks
- Authorization code exchanged server-side only

### Permission Enforcement

- All admin operations check permissions server-side
- UI hiding is for UX only, not security
- Database queries filtered by scene_id where applicable

---

## Migration Plan

### Phase 1: Database Setup

1. Create `users`, `admin_invites`, `user_sessions` tables
2. Add `submitted_by` columns to existing tables
3. Seed first Super Admin with your Discord ID

### Phase 2: Authentication

1. Set up Discord Developer Application
2. Add environment variables
3. Implement OAuth flow
4. Add login/logout UI

### Phase 3: Permission Scoping

1. Add permission checks to all admin operations
2. Implement permission-scoped sidebar
3. Filter admin queries by scene_id

### Phase 4: User Management

1. Build Manage Users UI (Super Admin)
2. Implement invite link generation
3. Implement direct promotion

---

## Testing Checklist

- [ ] Discord OAuth flow completes successfully
- [ ] New user created with 'viewer' role on first login
- [ ] Existing user recognized on subsequent logins
- [ ] Session persists across page refreshes
- [ ] Session survives browser close (within 30 days)
- [ ] Logout clears session
- [ ] Viewer cannot see admin tabs
- [ ] Scene Admin can see their scene's admin tabs
- [ ] Scene Admin cannot see other scenes' admin tabs
- [ ] Scene Admin cannot edit other scenes' data
- [ ] Super Admin can see all admin tabs
- [ ] Super Admin can promote users
- [ ] Invite links work correctly
- [ ] Expired invites are rejected
- [ ] Used invites cannot be reused

---

## Future Enhancements

- **Discord bot integration** - Post to channel when results submitted
- **Audit log** - Track all admin actions
- **User preferences sync** - Store scene preference in database for logged-in users
- **Regional Admin role** - Manage multiple scenes within a state (if needed)
- **Two-factor authentication** - Additional security for Super Admins

---

## References

- [Discord OAuth2 Documentation](https://discord.com/developers/docs/topics/oauth2)
- [httr2 Package](https://httr2.r-lib.org/)
- Region expansion design: `docs/plans/2026-02-04-region-expansion-design.md`
- Public submissions design: `docs/plans/2026-02-03-public-submissions-design.md`
