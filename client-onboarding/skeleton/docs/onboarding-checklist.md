# Checklist de Onboarding — ${{ values.clientTitle }}

## Fase 1: Configuración Inicial

- [ ] Registrar cliente en Backstage Catalog (completado automáticamente)
- [ ] Crear repositorio de documentación (completado automáticamente)
- [ ] Asignar account manager: **${{ values.accountManager }}**
- [ ] Configurar accesos al portal para el equipo del cliente
- [ ] Enviar credenciales de acceso al contacto principal: `${{ values.contactEmail }}`

## Fase 2: Infraestructura

- [ ] Provisionar entornos: desarrollo, staging, producción
- [ ] Configurar repositorios de código en GitHub
- [ ] Configurar pipelines de CI/CD (GitHub Actions u otro proveedor)
- [ ] Definir variables de entorno y secrets en el vault
- [ ] Configurar monitoreo y alertas

## Fase 3: Primeros Proyectos

- [ ] Crear primer proyecto usando el template "Nuevo Proyecto para Cliente"
- [ ] Revisar arquitectura propuesta con el equipo técnico del cliente
- [ ] Definir SLAs y niveles de soporte
- [ ] Configurar runbook de escalación de incidentes

## Fase 4: Operación

- [ ] Primera reunión de kick-off completada
- [ ] Accesos a herramientas de colaboración configurados
- [ ] Dashboard de costos configurado en Cost Insights
- [ ] Documentación técnica inicial publicada
- [ ] Revisión mensual agendada en el calendario

---

*Documento generado automáticamente el día del onboarding de ${{ values.clientTitle }}.*
