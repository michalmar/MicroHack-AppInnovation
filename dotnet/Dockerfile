# Multi-stage Dockerfile for LegoCatalog Blazor Server (Linux, .NET 8)
# Build with the SDK image, publish, and run on the smaller ASP.NET runtime image.

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy everything (Docker context will be the `dotnet` folder)
COPY . .

# Restore & publish the Blazor Server app
RUN dotnet restore "src/LegoCatalog.App/LegoCatalog.App.csproj"
RUN dotnet publish "src/LegoCatalog.App/LegoCatalog.App.csproj" -c Release -o /app/publish

#############################
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Create a non-root user for improved security
RUN useradd -m appuser || true

# Copy the published output from the build stage
COPY --from=build /app/publish ./

# Listen on 0.0.0.0:8080 by default so host port mapping works
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
EXPOSE 8080

# Prefer a non-root user
USER appuser

ENTRYPOINT ["dotnet", "LegoCatalog.App.dll"]
