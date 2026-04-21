# ─── Stage 1: Build ─────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project files and restore (layer caching)
COPY ["src/API/IntergalaxyTech.API.csproj",            "src/API/"]
COPY ["src/Application/IntergalaxyTech.Application.csproj", "src/Application/"]
COPY ["src/Domain/IntergalaxyTech.Domain.csproj",      "src/Domain/"]
COPY ["src/Infrastructure/IntergalaxyTech.Infrastructure.csproj", "src/Infrastructure/"]

RUN dotnet restore "src/API/IntergalaxyTech.API.csproj"

# Copy the rest of the source
COPY . .

# Publish
WORKDIR "/src/src/API"
RUN dotnet publish "IntergalaxyTech.API.csproj" -c Release -o /app/publish --no-restore

# ─── Stage 2: Runtime ────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Create a non-root user (security best practice for Azure)
RUN adduser --disabled-password --gecos "" appuser
USER appuser

# Copy published output
COPY --from=build /app/publish .

# Port exposure (Azure App Service uses PORT env variable)
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "IntergalaxyTech.API.dll"]
