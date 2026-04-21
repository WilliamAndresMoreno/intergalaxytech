# IntergalaxyTech API

Sistema de gestión de solicitudes de personajes del universo **Rick and Morty** para eventos y producciones audiovisuales — construido con **.NET 8 Web API**, Clean Architecture, EF Core y Docker.

---

## Decisión de Arquitectura

Se eligió **Arquitectura en Capas** con separación clara de responsabilidades:

```
IntergalaxyTech/
├── src/
│   ├── API/                  ← Controladores, Middleware, Extensions
│   ├── Application/          ← DTOs, Interfaces, Services, Validators
│   ├── Domain/               ← Entidades, Enums (sin dependencias externas)
│   └── Infrastructure/       ← EF Core, Repositories, HttpClient externo
└── tests/
    └── IntergalaxyTech.Tests/ ← xUnit + Moq
```

**¿Por qué no Clean Architecture completa?**  
Para una prueba técnica acotada (1–3 h), la arquitectura en capas ofrece la misma separación de responsabilidades y cumple con todos los principios SOLID requeridos (interfaces en Application, implementaciones en Infrastructure, lógica fuera del controlador) sin el overhead de proyectos adicionales (Core/UseCases/Ports). Clean Architecture agrega valor real en sistemas con múltiples front-ends o reglas de negocio muy complejas.

---

## Stack Técnico

| Tecnología | Versión | Uso |
|---|---|---|
| .NET Web API | 8.0 | Framework principal |
| Entity Framework Core | 8.0 | ORM con Migrations Code First |
| SQLite | — | Base de datos (local/Docker) |
| FluentValidation | 11.9 | Validaciones de request |
| Swashbuckle | 6.5 | Swagger / OpenAPI |
| xUnit + Moq | 2.6 / 4.20 | Pruebas unitarias |
| Docker + Compose | — | Contenerización |

---

## Correr Localmente (sin Docker)

### Prerrequisitos
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)

### Pasos

```bash
# 1. Clonar el repositorio
git clone https://github.com/<tu-usuario>/intergalaxytech-api.git
cd intergalaxytech-api

# 2. Restaurar dependencias
dotnet restore IntergalaxyTech.sln

# 3. Aplicar migraciones EF Core
dotnet ef database update --project src/Infrastructure/IntergalaxyTech.Infrastructure.csproj \
                          --startup-project src/API/IntergalaxyTech.API.csproj

# 4. Correr la API
dotnet run --project src/API/IntergalaxyTech.API.csproj
```

La API quedará disponible en:
- **Swagger UI**: http://localhost:5000 (raíz)
- **Health Check**: http://localhost:5000/health

---

## Correr con Docker y docker-compose

```bash
# 1. Copiar el archivo de variables de entorno
cp .env.example .env

# 2. Levantar los servicios
docker-compose up --build

# 3. Detener
docker-compose down
```

La API quedará disponible en **http://localhost:8080**

> **Nota Azure**: La variable `CONNECTION_STRING` en el `.env` simula lo que en producción sería un secreto en **Azure Key Vault** o una entrada en **App Service → Configuration → Application settings**.

---

## Migraciones EF Core

```bash
# Crear una migración nueva
dotnet ef migrations add <NombreMigracion> \
  --project src/Infrastructure/IntergalaxyTech.Infrastructure.csproj \
  --startup-project src/API/IntergalaxyTech.API.csproj

# Aplicar migraciones a la BD
dotnet ef database update \
  --project src/Infrastructure/IntergalaxyTech.Infrastructure.csproj \
  --startup-project src/API/IntergalaxyTech.API.csproj

# Revertir última migración
dotnet ef database update <MigracionAnterior> \
  --project src/Infrastructure/IntergalaxyTech.Infrastructure.csproj \
  --startup-project src/API/IntergalaxyTech.API.csproj
```

---

## Pruebas Unitarias

```bash
# Correr todos los tests
dotnet test IntergalaxyTech.sln --verbosity normal

# Con reporte de cobertura
dotnet test IntergalaxyTech.sln --collect:"XPlat Code Coverage"
```

**Tests incluidos:**

| Test | Cobertura |
|---|---|
| `ImportarPersonajes_DebeImportarSoloPersonajesNuevos` | Evita duplicados en la importación |
| `ImportarPersonajes_CuandoTodosSonNuevos_DebeImportarTodos` | Importa correctamente todos los nuevos |
| `CrearSolicitud_ConPersonajeExistente_DebeCrearSolicitudEnEstadoPendiente` | Crea solicitud con estado inicial correcto |
| `CrearSolicitud_ConPersonajeInexistente_DebeLanzarKeyNotFoundException` | Valida existencia del personaje |
| `ActualizarEstado_TransicionValida_DebeActualizarCorrectamente` (Theory × 4) | Todas las transiciones permitidas |
| `ActualizarEstado_TransicionInvalida_DebeLanzarInvalidOperationException` (Theory × 3) | Bloquea transiciones inválidas |
| `ActualizarEstado_SolicitudInexistente_DebeLanzarKeyNotFoundException` | 404 en solicitud no encontrada |

---

## Endpoints Disponibles

### Personajes
```
POST   /api/personajes/importar?paginas={n}   Importar desde Rick and Morty API
GET    /api/personajes?nombre=&estado=&page=&pageSize=  Listar (paginado + filtros)
GET    /api/personajes/{id}                   Detalle de un personaje
```

### Solicitudes
```
POST   /api/solicitudes                       Crear nueva solicitud
GET    /api/solicitudes?estado=&solicitante=&page=&pageSize=  Listar con filtros
GET    /api/solicitudes/{id}                  Detalle
PATCH  /api/solicitudes/{id}/estado           Cambiar estado (valida transiciones)
```

### Reportes y Salud
```
GET    /api/reportes/solicitudesresumen       Resumen por estado + personaje más solicitado
GET    /health                                Health check (requerido por Azure App Service)
```

---

## Diseño para Azure

| Necesidad del sistema | Servicio Azure | Razón |
|---|---|---|
| Hospedar la API .NET 8 | **Azure App Service (Linux)** | PaaS gestionado, escala automática, integración nativa con Key Vault y Application Insights, deploy desde Docker o GitHub Actions sin gestionar VMs. |
| Base de datos relacional | **Azure SQL Database** | SQL Server gestionado, backups automáticos, geo-replicación, firewall por IP, compatible 100% con EF Core. La cadena de conexión ya está preparada en `appsettings.json`. |
| Almacenar archivos/reportes PDF | **Azure Blob Storage** | Almacenamiento de objetos de bajo costo, SAS tokens para acceso temporal seguro, SDKs oficiales para .NET. |
| Exponer y versionar la API hacia terceros | **Azure API Management (APIM)** | Gateway con control de versiones, throttling, autenticación OAuth2/API Key, portal para desarrolladores y analytics de uso. |
| Ejecutar tareas programadas o eventos async | **Azure Functions** (timer trigger / queue trigger) | Serverless, pago por ejecución, ideal para importaciones programadas (ej: importar nuevos personajes cada noche) o procesar eventos en cola (Azure Service Bus). |

---

## Ejercicio de Migración — Web Forms → .NET 8

### Problemas identificados en el código legado

1. **Credenciales hardcodeadas** (`User Id=admin;Password=admin123`): exposición directa de credenciales de producción en el código fuente. Cualquier developer con acceso al repo tiene acceso a la BD.

2. **SQL Injection** (`"INSERT INTO ... VALUES (" + ddlPersonaje.SelectedValue + ", '" + txtSolicitante.Text + "'")`): concatenación directa de input del usuario sin parametrizar. Un atacante puede ejecutar SQL arbitrario.

3. **Violación de Single Responsibility / mezcla de capas**: el `code-behind` combina UI, validaciones, lógica de negocio y acceso a datos en un mismo método. Es imposible testear de forma aislada.

4. **Gestión manual de conexiones sin abstracción**: `SqlConnection`, `SqlCommand` y `SqlDataReader` directamente en el `code-behind`. Cualquier cambio de BD o de ORM requiere tocar la capa de presentación.

5. **Estado en sesión para comunicación entre páginas** (`Session["ultimaSolicitud"]`): fragilidad ante múltiples pestañas, usuarios concurrentes y reinicio del servidor.

6. **Sin manejo de errores**: ningún `try/catch`; cualquier fallo de BD o de validación resulta en una excepción sin capturar expuesta al usuario.

### Solución equivalente en .NET 8

```csharp
// ─── Controller ───────────────────────────────────────────────────
[HttpPost]
public async Task<IActionResult> CrearSolicitud([FromBody] CrearSolicitudRequest request)
{
    var validation = await _crearValidator.ValidateAsync(request);
    if (!validation.IsValid)
        return BadRequest(new { errores = validation.Errors.Select(e => e.ErrorMessage) });

    var solicitud = await _solicitudService.CrearSolicitudAsync(request);
    return CreatedAtAction(nameof(GetSolicitud), new { id = solicitud.Id }, solicitud);
}

// ─── Service (lógica de negocio aislada y testeable) ──────────────
public async Task<SolicitudDto> CrearSolicitudAsync(CrearSolicitudRequest request)
{
    var personaje = await _personajeRepository.GetByIdAsync(request.PersonajeId)
        ?? throw new KeyNotFoundException($"Personaje {request.PersonajeId} no encontrado.");

    var solicitud = new Solicitud
    {
        PersonajeId    = request.PersonajeId,
        Solicitante    = request.Solicitante,   // ← EF Core parametriza automáticamente
        Evento         = request.Evento,
        FechaEvento    = request.FechaEvento,
        Estado         = EstadoSolicitud.Pendiente,
        FechaCreacion  = DateTime.UtcNow,
        FechaActualizacion = DateTime.UtcNow
    };

    await _solicitudRepository.AddAsync(solicitud);
    await _solicitudRepository.SaveChangesAsync();   // ← EF Core maneja la transacción
    return MapToDto(solicitud, personaje);
}
```

**Mejoras clave vs. el código legado:**
- Credenciales en variables de entorno / Key Vault, nunca en el código.
- EF Core parametriza todas las queries → SQL Injection imposible.
- Validaciones en `FluentValidation` (capa Application), desacopladas del controlador.
- Manejo global de errores via `GlobalExceptionMiddleware`.
- Cada capa tiene una única responsabilidad y es 100% testeable con mocks.

---

## Preguntas de Liderazgo Técnico

### 1. ¿Cómo planificarías la migración completa del sistema legado en etapas graduales?

**Fase 0 — Auditoría y baseline** (1–2 semanas)  
Levantar el inventario completo de formularios, stored procedures, tablas y dependencias del sistema Web Forms. Definir métricas de calidad (cobertura de tests, tiempo de respuesta) para comparar antes y después.

**Fase 1 — Infraestructura y CI/CD** (1 semana)  
Crear el repositorio con la arquitectura en capas, pipeline CI/CD (GitHub Actions), entornos (Dev/Staging/Prod) en Azure App Service. Sin migrar funcionalidad aún.

**Fase 2 — Módulos de solo lectura** (2–3 semanas)  
Migrar primero los endpoints GET (listados, detalles). Bajo riesgo; permiten validar la arquitectura y el pipeline de despliegue con usuarios reales sin afectar escrituras.

**Fase 3 — Módulos de escritura críticos** (3–4 semanas por módulo)  
Migrar las escrituras módulo a módulo, comenzando por los de menor tráfico. Cada módulo incluye: dominio, repositorio, servicio, controlador y tests unitarios + de integración.

**Fase 4 — Retirar el legado módulo a módulo**  
Cuando un módulo nuevo lleva 2+ semanas en producción sin incidentes, se desactiva el equivalente Web Forms. No apagarlo todo a la vez.

**Fase 5 — Optimización post-migración**  
Ajustar índices de BD, configurar Application Insights, revisar alertas y SLA.

---

### 2. ¿Qué estrategia usarías si el sistema legado debe operar en paralelo durante la transición?

**Patrón Strangler Fig**: el nuevo sistema "estrangula" gradualmente al legado exponiéndose bajo la misma URL base a través de un API Gateway (Azure API Management o un nginx reverse proxy). El gateway enruta cada path al sistema correcto según el estado de la migración:

```
/api/solicitudes  → Nueva API (.NET 8)   [ya migrado]
/api/reportes     → Legado Web Forms     [pendiente]
```

Adicionalmente:
- **Base de datos compartida temporalmente**: el nuevo sistema apunta a la misma BD que el legado durante la transición, usando vistas o esquemas separados para evitar conflictos. Una vez migrado un módulo completo, se retira el acceso del legado a esas tablas.
- **Feature flags**: habilitar/deshabilitar la nueva implementación por entorno o porcentaje de tráfico (Azure App Configuration). Permite hacer rollback instantáneo sin redespliegue.
- **Sincronización de datos**: si hay escrituras duplicadas en el período de transición, un job (Azure Function) sincroniza ambas BDs hasta que el legado se apague.

---

### 3. ¿Cómo organizarías a un equipo de 3 desarrolladores para este módulo?

**Roles sugeridos:**

| Dev | Rol | Responsabilidades |
|---|---|---|
| Dev 1 (Senior / Tech Lead) | Arquitectura + Infrastructure | Diseño de capas, EF Core, migrations, repositorios, integración Rick and Morty API, revisión de PRs, resolución de bloqueos técnicos. |
| Dev 2 (Semi-Senior) | Application + Domain | Servicios, validaciones, lógica de negocio, DTOs, state machine de solicitudes, pruebas unitarias de servicios. |
| Dev 3 (Junior / Mid) | API Layer + Tests de integración | Controladores, Swagger, middleware, health check, pruebas de integración de endpoints, documentación README. |

**Estrategia de ramas Git (Git Flow simplificado):**

```
main          ← producción (protegida, solo merge desde staging)
  └── staging ← pre-producción (CI/CD automático)
        └── develop ← integración continua
              ├── feature/importar-personajes
              ├── feature/crud-solicitudes
              └── feature/reportes
```

**Code Reviews:**
- Toda feature branch requiere al menos **1 aprobación** (2 si toca dominio o infraestructura).
- El Tech Lead hace la aprobación final en PRs que afecten la arquitectura o el schema de BD.
- Checklist de PR: tests pasan, sin warnings de build, Swagger actualizado, sin secrets en código.

**Ceremonias ligeras:** daily standup de 15 min, revisión técnica semanal de 30 min para compartir decisiones de diseño entre los tres.

---

## Herramientas de IA Utilizadas

- **Gemini** — Generación código de capas, tests unitarios, análisis del código legado y documentación.
