# ${{ values.serviceTitle }}

${{ values.serviceDescription }}

## Registro en Backstage

Este servicio está registrado en el Catalog como `Component` dentro del sistema `${{ values.projectRef }}`.

```yaml
spec:
  type: ${{ values.serviceType }}
  system: ${{ values.projectRef }}
  owner: ${{ values.clientRef }}
```
