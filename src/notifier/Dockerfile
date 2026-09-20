FROM mcr.microsoft.com/dotnet/sdk:10.0

WORKDIR /app
COPY *.cs .
COPY appsettings.json .
COPY *.csproj .
RUN --mount=type=cache,target=/root/.nuget/packages dotnet publish -c Release -o out

ENV ASPNETCORE_HTTP_PORTS=5000

ENV OTEL_DOTNET_AUTO_TRACES_ADDITIONAL_SOURCES="notifier"
ENV OTEL_DOTNET_AUTO_METRICS_ADDITIONAL_SOURCES="notifier"

ENTRYPOINT [ "./out/Notifier", "--urls", "http://*:5000" ]