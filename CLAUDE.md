# EventRadar

Event discovery and management platform. Collects public events; attendees browse and register.

## Structure

- `api/` — Laravel API and Filament admin panel
- `frontend/` — Quasar/Vue customer-facing UI

## Development Flow

### 1. Plan
Ask the user when genuinely uncertain about requirements. Make independent decisions on implementation details — don't ask about things you can reasonably decide yourself.

### 2. Build
- Layered architecture: `Controller → Service → Repository`
- Controllers accept `FormRequest` for input validation, return `JsonResource`. No success/data wrappers.
- All database access through repositories — never build queries outside them.
- Services and repositories must have interfaces, bound in `AppServiceProvider`.
- Inject dependencies via constructor.
- Use DB transactions where data integrity requires it.

### 3. Test
Write unit tests for service logic. Mock repositories and other services — test only the unit under test.

For frontend, use Playwright with Page Object Model. Pages handle navigation, components wrap locators and expose interaction methods. Tests stay clean by delegating all selectors and actions to these classes.

### 4. Review
Self-check for repeated logic, clear domain separation, and adherence to the layered architecture before finishing.

### 5. Ship
Commit with conventional commits (`feat:`, `fix:`, `refactor:`, etc.). No co-author attribution.

## Memory

Use **only** the MCP knowledge graph for all persistent memory. Do not use the file-based auto-memory system (markdown files). The graph is stored in `.claude/memory.jsonl` and shared across all developers via git.

- Before touching any module/class → `mcp__memory__search_nodes("{name}")`. Catches prior decisions.
- Save new decisions with `mcp__memory__create_entities` or `mcp__memory__add_observations`.
- `/memory` = full graph, `/memory <term>` = search.

## Self-Improve

Invoke `self-improve` skill when:
- User says "remember/always/never/from now on" → static (edit skill or CLAUDE.md)
- Library chosen over alternative → dynamic (knowledge graph)
- Non-obvious bug fixed due to wrong assumption → dynamic
- Architectural constraint discovered → dynamic
