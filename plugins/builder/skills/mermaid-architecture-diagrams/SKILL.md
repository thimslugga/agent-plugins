---
name: "mermaid-architecture-diagrams"
description: "Generate architecture diagrams in Mermaid syntax showing how application components connect — lambdas, databases, APIs, frontends, and external services."
---

# Mermaid Architecture Diagrams

Generates architecture diagrams as markdown files using Mermaid syntax.

## Output Format

The output shows how application components fit together — backend services, databases, external APIs, frontends, and cloud infrastructure — in a single visual diagram. Each diagram is output as a markdown file inside a folder named after the diagram, containing only a title and the Mermaid code block.

Every generated diagram MUST follow this exact structure:

```markdown
# {Diagram Title}

```mermaid
{mermaid diagram code}
```

```text

Nothing else. No descriptions, no explanations, no additional headings. One title, one mermaid block.

## Output Location

Create a folder named after the diagram (kebab-case) and place a single `README.md` inside it:

```

{diagram-name}/
└── README.md

```text

Example: if the user asks for a "Payment Processing Architecture" diagram, create:

```

payment-processing-architecture/
└── README.md

```text

## Diagram Construction Rules

### Diagram Type Selection

Use the Mermaid diagram type that best represents the architecture:

| Scenario | Mermaid Type |
|----------|--------------|
| General service-to-service flow | `flowchart TD` or `flowchart LR` |
| Request/response sequences between services | `sequenceDiagram` |
| Layered architecture with groupings | `flowchart TD` with `subgraph` |

Default to `flowchart TD` with subgraphs unless the user specifies otherwise or the architecture clearly benefits from a different type.

### Naming Conventions

- Use the actual names of services, functions, and resources the user provides
- Label nodes with both the service type and specific name when available
- Example: `lambdaAuth["Lambda: auth-handler"]` not just `lambda["Lambda"]`

### Subgraph Grouping

Group related components into subgraphs by layer or domain:

- **Frontend** — web apps, mobile apps, dashboards
- **API Layer** — API Gateway, load balancers, CDN
- **Compute** — Lambda functions, ECS tasks, EC2 instances
- **Data** — DynamoDB, RDS, S3, ElastiCache
- **External** — third-party APIs, SaaS services, webhooks

### Connection Labels

Label edges with the interaction type when it adds clarity:

- HTTP/REST calls
- Event triggers (SNS, SQS, EventBridge)
- Database reads/writes
- WebSocket connections
- SDK calls

### Style Guidelines

- Use directional flow (top-down or left-right) that reflects the request path
- Keep the diagram readable — if it exceeds ~20 nodes, consider splitting into subgraphs or suggesting multiple diagrams
- Use consistent node shapes:
  - `["..."]` for services and applications
  - `[("...")]` for databases/storage
  - `{{"..."}}` for external services
  - `(["..."])` for queues/streams

## Example

User asks: "Show me the architecture for my order processing system. It has a React frontend, API Gateway, three lambdas (create-order, process-payment, send-notification), a DynamoDB orders table, and it calls Stripe for payments."

Output file: `order-processing-architecture/README.md`

```markdown
# Order Processing Architecture

````mermaid
flowchart TD
    subgraph Frontend
        react["React App"]
    end

    subgraph API Layer
        apigw["API Gateway"]
    end

    subgraph Compute
        createOrder["Lambda: create-order"]
        processPayment["Lambda: process-payment"]
        sendNotification["Lambda: send-notification"]
    end

    subgraph Data
        ordersTable[("DynamoDB: orders")]
    end

    subgraph External
        stripe{{"Stripe API"}}
    end

    react -->|"HTTP"| apigw
    apigw --> createOrder
    createOrder -->|"write"| ordersTable
    createOrder --> processPayment
    processPayment -->|"charge"| stripe
    processPayment --> sendNotification
````

```text

## Workflow

1. User describes their application architecture — services, connections, and infrastructure
2. Identify all components and categorize them by layer
3. Determine the best Mermaid diagram type
4. Generate the diagram with proper subgraphs, labels, and connections
5. Output the markdown file in `{diagram-name}/README.md`

## Best Practices

- Ask clarifying questions if the architecture description is ambiguous or incomplete
- Use the specific resource names the user provides rather than generic labels
- Show the direction of data/request flow with arrow labels
- Group by logical layer, not by AWS service type
- If the system is complex, suggest breaking it into multiple focused diagrams (e.g., one for the data pipeline, one for the API layer)
