# Servidor de Aluminios para Render (u otro servicio con Docker).
# Render define PORT; Program.cs escucha en ese puerto.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish Aluminios.Api/Aluminios.Api.csproj -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_ENVIRONMENT=Production
ENTRYPOINT ["dotnet", "Aluminios.Api.dll"]
