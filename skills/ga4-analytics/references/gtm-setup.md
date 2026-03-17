# GTM Setup & Configuration

## Table of Contents
1. Container Structure
2. Variables Setup
3. Trigger Configuration
4. Tag Configuration
5. Workspace & Version Management

---

## 1. Container Structure

Organize GTM with a consistent folder structure:

```
GTM Container
├── Tags/
│   ├── GA4 - Configuration
│   ├── GA4 - Activation/
│   │   ├── GA4 - bot_created
│   │   ├── GA4 - bot_published
│   │   └── GA4 - channel_connected
│   ├── GA4 - Features/
│   │   ├── GA4 - feature_viewed
│   │   └── GA4 - feature_used
│   ├── GA4 - Errors/
│   │   └── GA4 - error_api_failed
│   └── GA4 - Performance/
│       └── GA4 - performance_page_loaded
├── Triggers/
│   ├── Custom Event - bot_created
│   ├── Custom Event - bot_published
│   └── ... (one per event)
└── Variables/
    ├── DLV - event_params.bot_type
    ├── DLV - event_params.plan
    └── ... (one per parameter)
```

---

## 2. Variables Setup

### User-Defined Variables — Data Layer Variables (DLV)

Create one DLV per parameter you want to pass to GA4:

| Variable Name | Data Layer Variable Name | Default Value |
|---|---|---|
| `DLV - event_params.bot_type` | `event_params.bot_type` | `(undefined)` |
| `DLV - event_params.plan` | `event_params.plan` | `(undefined)` |
| `DLV - event_params.is_first_publish` | `event_params.is_first_publish` | `(undefined)` |
| `DLV - event_params.time_to_complete_ms` | `event_params.time_to_complete_ms` | `(undefined)` |
| `DLV - user_properties.plan` | `user_properties.plan` | `(undefined)` |
| `DLV - user_properties.org_id` | `user_properties.org_id` | `(undefined)` |

**Naming rule:** `DLV - {path}` — makes variables scannable in dropdowns.

### Built-in Variables to Enable

Go to **Variables** → **Configure** → enable:
- Page URL
- Page Path
- Page Title
- Click Element
- Click Text (for debugging only)

---

## 3. Trigger Configuration

Create one Custom Event trigger per BOTNOI event:

**Trigger: `bot_created`**
```
Trigger Type: Custom Event
Event Name:   bot_created
This trigger fires on: All Custom Events
```

Repeat for every event in the taxonomy. Do NOT use regex to match multiple events
in one trigger — one event, one trigger, easier to debug.

---

## 4. Tag Configuration

### GA4 Configuration Tag (fire on all pages)

```
Tag Type:           Google Analytics: GA4 Configuration
Measurement ID:     G-XXXXXXXXXX
Send page view:     false  (Angular Router handles this)
User Properties:
  plan:    {{DLV - user_properties.plan}}
  org_id:  {{DLV - user_properties.org_id}}
Firing Trigger:     All Pages
```

### GA4 Event Tag (one per event)

Example for `bot_created`:

```
Tag Type:           Google Analytics: GA4 Event
Configuration Tag:  GA4 Configuration (select the tag above)
Event Name:         bot_created

Event Parameters:
  bot_type:              {{DLV - event_params.bot_type}}
  template_used:         {{DLV - event_params.template_used}}
  channel_count:         {{DLV - event_params.channel_count}}
  time_to_complete_ms:   {{DLV - event_params.time_to_complete_ms}}

Firing Trigger:     bot_created (the trigger from step 3)
```

---

## 5. Workspace & Version Management

### Workflow before publishing

1. **Work in a named workspace** — never edit in Default workspace directly
   - Create: `Workspace: Sprint 34 - Bot creation tracking`
2. **Preview and validate** — use GTM Preview + GA4 DebugView
3. **Get review** — another team member checks tag/trigger/variable mapping
4. **Publish with version notes**:
   ```
   Version: 24
   Notes: Added bot_created, bot_published, channel_connected events
          Removed deprecated: click_create_button
   ```

### Naming conventions

| Item | Format | Example |
|---|---|---|
| Tag | `GA4 - {event_name}` | `GA4 - bot_created` |
| Trigger | `Custom Event - {event_name}` | `Custom Event - bot_created` |
| DLV | `DLV - {path}` | `DLV - event_params.bot_type` |
| Workspace | `Sprint {N} - {description}` | `Sprint 34 - Bot creation tracking` |

Never publish without a version note. A version note is your audit trail when something breaks.
