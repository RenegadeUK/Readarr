# Readarr Development Guide for AI Agents


# Readarr stability fork goals

- Primary goal: prevent crashes from malformed/partial metadata responses.
- Treat all external metadata as untrusted input (nulls, missing fields, empty arrays).
- Prefer null-coalescing to empty enumerables/lists.
- Avoid wide refactors. Keep diffs small and test-backed.
- Add or update tests for any null-handling changes.
- Do not change DB schema or API contracts unless explicitly requested.


## Project Overview
Readarr is an ebook/audiobook collection manager built with .NET 6 (C#) backend and React/Redux frontend. The project uses a monorepo structure with separate backend and frontend build systems.

## Architecture

### Backend (.NET/C#)
- **Framework**: .NET 6, ASP.NET Core for web hosting
- **DI Container**: DryIoc with custom rules (`WithNzbDroneRules()`)
- **Assembly Structure**: 5 core assemblies auto-loaded via `Bootstrap.ASSEMBLIES`:
  - `Readarr.Host` - Application bootstrap and hosting
  - `Readarr.Core` - Business logic and domain services
  - `Readarr.SignalR` - Real-time notifications
  - `Readarr.Api.V1` - REST API controllers
  - `Readarr.Http` - HTTP infrastructure
- **Namespace Convention**: `NzbDrone.*` for legacy compatibility (e.g., `NzbDrone.Core`, `NzbDrone.Common`)
- **Database**: SQLite (default) or PostgreSQL with Dapper for queries, custom migration system

### Event-Driven Architecture
Services implement `IHandle<TEvent>` or `IHandleAsync<TEvent>` for domain events:
```csharp
public class QueueService : IQueueService, IHandle<TrackedDownloadRefreshedEvent>
{
    public void Handle(TrackedDownloadRefreshedEvent message) { }
}
```
Events are published via `IEventAggregator` and auto-wired by DI container.

### API Layer
- **Pattern**: Controllers inherit from `RestController<TResource>` or `RestControllerWithSignalR<TResource, TModel>`
- **Routing**: `[V1ApiController]` attribute auto-prefixes routes with `/api/v1`
- **Validation**: FluentValidation with `PostValidator`, `PutValidator`, `SharedValidator` in controllers
- **Custom Attributes**: 
  - `[RestPostById]`, `[RestPutById]`, `[RestDeleteById]` for CRUD
  - `[SkipValidation]` to bypass validation
- **Provider Pattern**: Download clients, indexers, notifications use `ProviderControllerBase` with test endpoints

### Frontend (React/Redux)
- **State Management**: Redux with custom thunk/action creators in `Store/Actions/`
- **Build**: Webpack outputs to `_output/UI/`
- **Module Resolution**: Absolute imports from `frontend/src/` (e.g., `import { createThunk } from 'Store/thunks'`)
- **API Communication**: All API calls through Redux thunks

## Development Workflow

### Building
```bash
# Backend only (from repo root)
dotnet msbuild -restore src/Readarr.sln -p:Configuration=Debug -p:Platform=Posix

# Or use VS Code task: "build dotnet"

# Frontend (watch mode)
yarn watch  # from repo root

# Full build
./build.sh  # includes frontend, backend, and packaging
```

### Testing
```bash
# Backend tests
./test.sh Linux Unit          # Unit tests only
./test.sh Linux Integration   # Integration tests

# Test categories: ManualTest, IntegrationTest, AutomationTest, WINDOWS, LINUX
```

### Running Locally
```bash
# After building, run from _output:
cd _output
./Readarr.Console.exe  # or Readarr.exe on Windows
```
Default port: 8787

## Key Patterns & Conventions

### Service Layer
- Services are singleton by default (via `WithNzbDroneRules()`)
- Database access through repository pattern: `BasicRepository<T>` or `IBasicRepository<T>`
- Lazy-loaded relationships using Dapper join queries
- Quality profiles, metadata profiles, and custom formats are core domain concepts

### Testing
- **Base Classes**: 
  - `TestBase<TSubject>` - Unit tests with AutoMoq container
  - `CoreTest` - Extends TestBase for core layer
  - `DbTest` - Integration tests with real database (SQLite or Postgres)
- **Patterns**:
  - Use `Subject` property to get auto-mocked instance under test
  - `Mocker.GetMock<IService>()` for mock setup
  - FluentAssertions for assertions
  - FizzWare.NBuilder for test data builders

Example:
```csharp
[TestFixture]
public class QueueServiceFixture : CoreTest<QueueService>
{
    [SetUp]
    public void Setup()
    {
        Mocker.GetMock<ITrackedDownloadService>()
            .Setup(x => x.GetTrackedDownloads())
            .Returns(new List<TrackedDownload>());
    }

    [Test]
    public void should_process_queue_items()
    {
        Subject.GetQueue().Should().BeEmpty();
    }
}
```

### Configuration
- `config.xml` in app data folder (auto-created)
- Options pattern: `PostgresOptions`, `AuthOptions`, etc. from `Readarr:*` config sections
- `IConfigFileProvider` for runtime config access

### Startup Sequence
1. `Bootstrap.Start()` → detects application mode (Console/Service/Utility)
2. Creates `HostBuilder` with DryIoc service provider
3. `AutoAddServices()` scans assemblies, registers services
4. `Startup.Configure()` initializes databases, migrations, event aggregator
5. `ApplicationStartingEvent` → `ApplicationStartedEvent` published

### Data Flow
Books/Authors → Editions → BookFiles → Download tracking → Quality profiles → Custom formats

### Common Gotchas
- **Project Names**: Physical folder `NzbDrone.*` but assembly names are `Readarr.*`
- **Database Migrations**: Use `MigrationContext` and inherit from `NzbDroneMigrationBase`
- **SignalR**: Use `IBroadcastSignalRMessage` to push updates to frontend
- **Path Handling**: Always use `IAppFolderInfo` for app paths, not hardcoded strings
- **Platform Detection**: `OsInfo.IsWindows`, `OsInfo.IsLinux`, `OsInfo.IsMacOS`

## Project Status
⚠️ **Note**: Readarr has been officially retired but continues to be maintained by the community. The metadata source was the primary issue - third-party mirrors exist but are not officially supported.

## Working on Current Branch: `fix/bookinfo-null-safety`
This branch is focused on null safety improvements. When making changes:
- Use nullable reference types appropriately
- Add null checks before accessing properties
- Consider using `?.` and `??` operators
- Update tests to cover null scenarios
