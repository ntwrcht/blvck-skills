# Diagrams

Pick the diagram that answers the question being asked. A diagram that shows everything shows nothing.

## Selection

| Question the reader has | Diagram |
| :--- | :--- |
| What is this system, and who or what talks to it? | C4 Context |
| What gets deployed, and how do the pieces communicate? | C4 Container |
| What is inside this one service? | C4 Component |
| What happens, in order, when someone does X? | Sequence |
| What does the database look like? | ER |
| What states can this record be in? | State |
| How does this business process branch? | Flowchart |
| What runs on which machine or cluster? | Deployment |

**State vs flowchart:** a state diagram tracks one entity's lifecycle (`Order: pending → paid → shipped`). A flowchart tracks a process with decisions (registration, checkout). Choosing the wrong one produces a diagram nobody can read.

## C4 levels

| Level | Shows | Audience | When |
| :--- | :--- | :--- | :--- |
| 1 — Context | The system as one box, plus users and external systems | Anyone, including non-technical | Always |
| 2 — Container | Deployable units: apps, APIs, databases, queues | Tech leads, architects | Almost always |
| 3 — Component | Modules inside one container | Developers on that container | Only for containers complex enough to need it |
| 4 — Code | Classes | Rarely useful | Skip — the code is the diagram |

Zoom in only where the complexity is. Three Context diagrams for three services beat one Component diagram of everything.

## Mermaid

Prefer Mermaid: it renders in GitHub, GitLab, and most doc sites without a build step.

**C4 Context**

```mermaid
C4Context
  title System Context — Task API
  Person(user, "Team member", "Creates and tracks tasks")
  System(taskapi, "Task API", "Spring Boot service")
  System_Ext(auth, "Okta", "OIDC identity provider")
  System_Ext(mail, "SendGrid", "Transactional email")
  Rel(user, taskapi, "Uses", "HTTPS")
  Rel(taskapi, auth, "Validates tokens", "OIDC")
  Rel(taskapi, mail, "Sends assignment notices", "REST")
```

**C4 Container**

```mermaid
C4Container
  title Containers — Task API
  Person(user, "Team member")
  Container_Boundary(sys, "Task platform") {
    Container(web, "Web app", "React", "Task UI")
    Container(api, "API", "Spring Boot", "REST endpoints, business rules")
    ContainerDb(db, "Task store", "PostgreSQL 15", "Tasks, projects, members")
    Container(worker, "Notifier", "Spring Boot", "Consumes task events")
  }
  Rel(user, web, "Uses", "HTTPS")
  Rel(web, api, "Calls", "JSON/HTTPS")
  Rel(api, db, "Reads and writes", "JDBC")
  Rel(api, worker, "Publishes task events", "RabbitMQ")
```

**Sequence**

```mermaid
sequenceDiagram
  actor U as Team member
  participant A as API
  participant D as PostgreSQL
  participant Q as RabbitMQ
  U->>A: POST /tasks
  A->>A: Validate bearer token
  A->>D: INSERT INTO tasks
  D-->>A: task id
  A->>Q: publish TaskCreated
  A-->>U: 201 Created
```

**ER**

```mermaid
erDiagram
  PROJECT ||--o{ TASK : contains
  MEMBER ||--o{ TASK : "assigned to"
  TASK {
    uuid id PK
    uuid project_id FK
    string title
    string status
    timestamp created_at
  }
```

**State**

```mermaid
stateDiagram-v2
  [*] --> pending
  pending --> in_progress: claim
  in_progress --> completed: finish
  in_progress --> pending: release
  completed --> [*]
```

## Rules

- **Label every relationship** with both the action and the protocol: "Reads and writes / JDBC", never a bare arrow.
- **Name the technology** on each container. "API" is useless; "API — Spring Boot 3.2" is documentation.
- **One diagram, one level.** Mixing containers and classes in one picture is the most common failure.
- **Diagram what the code shows.** If the manifest declares three replicas, the deployment diagram shows three.
- **Keep the source in the repo.** Commit the Mermaid block in Markdown, not an exported PNG — an image cannot be diffed or corrected.
- **Cap it at roughly nine boxes.** Past that, split into a parent diagram and a zoomed child.

## PlantUML

Reach for PlantUML only when Mermaid cannot express the diagram — detailed deployment topologies, complex class hierarchies, or when the repo already standardizes on `.puml`. It needs a renderer, so match whatever the project already uses.
