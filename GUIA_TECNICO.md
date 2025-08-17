# 🛠️ Guía Rápida para Técnicos de Soporte

## 🚨 Situaciones de Emergencia

### "La computadora no arranca"
1. **SI arranca pero va lenta:** `problem_detector.ps1`
2. **SI arranca en modo seguro:** `escaneo_seguridad.ps1`
3. **SI necesitas datos:** `recuperacion_archivos.ps1`

### "Internet no funciona"
1. **Diagnóstico rápido:** `diagnostico_red.ps1`
2. **Si sigue fallando:** `diagnostico_completo.ps1` (sección red)

### "Todo va muy lento"
1. **Primera opción:** `problem_detector.ps1`
2. **Análisis detallado:** `diagnostico_rendimiento.ps1`
3. **Limpieza:** `limpieza_mantenimiento.ps1`

---

## 📋 Lista de Verificación por Script

### ✅ `quick_assessment.ps1` (2-3 min)
**Antes de ejecutar:**
- [ ] Cerrar programas innecesarios
- [ ] Asegurar conexión estable

**Qué verifica:**
- [ ] CPU usage (normal < 70%)
- [ ] Memoria libre (crítico < 10%)
- [ ] Conectividad básica de red
- [ ] Gateway accesible

### ✅ `problem_detector.ps1` (3-5 min)
**Busca automáticamente:**
- [ ] Discos con poco espacio (< 20%)
- [ ] Procesos que consumen mucha CPU/memoria
- [ ] Servicios críticos detenidos
- [ ] Problemas de conectividad

### ✅ `diagnostico_completo.ps1` (5-10 min)
**Para reportes profesionales:**
- [ ] Inventario completo de hardware
- [ ] Lista de software instalado
- [ ] Análisis de rendimiento detallado
- [ ] Configuración de red completa
- [ ] Recomendaciones específicas

---

## 🎯 Casos de Uso Específicos

### 📞 **Cliente llama: "La PC va lenta"**
```
1. quick_assessment.ps1     (estado general)
2. problem_detector.ps1     (encontrar causa)
3. diagnostico_rendimiento.ps1  (detalles)
4. limpieza_mantenimiento.ps1   (solución)
```

### 💼 **Visita técnica programada**
```
1. backups.ps1              (proteger datos)
2. diagnostico_completo.ps1  (reporte inicial)
3. [realizar cambios]
4. diagnostico_completo.ps1  (reporte final)
```

### 🔍 **Auditoría de equipos**
```
1. inventario_hw_sw.ps1     (hardware/software)
2. escaneo_seguridad.ps1    (estado seguridad)
3. diagnostico_completo.ps1  (reporte ejecutivo)
```

### 🆘 **Recuperación de datos**
```
1. recuperacion_archivos.ps1  (buscar archivos)
2. backups.ps1               (respaldar encontrados)
3. validacion_usuario.ps1     (verificar permisos)
```

---

## ⏱️ Tiempos Estimados por Script

| Script | Tiempo | Uso recomendado |
|--------|--------|-----------------|
| `quick_assessment.ps1` | 2-3 min | Primera evaluación |
| `problem_detector.ps1` | 3-5 min | Encontrar problemas |
| `diagnostico_red.ps1` | 2-4 min | Problemas de internet |
| `diagnostico_rendimiento.ps1` | 3-5 min | Análisis de lentitud |
| `diagnostico_completo.ps1` | 5-10 min | Reporte profesional |
| `inventario_hw_sw.ps1` | 4-6 min | Inventario completo |
| `escaneo_seguridad.ps1` | 3-7 min | Verificación seguridad |
| `limpieza_mantenimiento.ps1` | 5-15 min | Optimización |
| `backups.ps1` | Variable | Respaldo datos |
| `recuperacion_archivos.ps1` | 5-20 min | Buscar archivos |

---

## 🔧 Solución Rápida de Problemas

### ❌ Error: "No se puede ejecutar scripts"
```powershell
# Solución rápida:
powershell -ExecutionPolicy Bypass .\script_name.ps1

# O usar el .bat:
ejecutar_master.bat
```

### ❌ Script se ejecuta pero no genera reporte
- Verificar carpeta `logs_reports\`
- Ejecutar como administrador
- Verificar espacio en disco

### ❌ "Access denied" o errores de permisos
- Ejecutar PowerShell como administrador
- Verificar que el usuario tenga permisos en la carpeta
- Usar `validacion_usuario.ps1` para verificar permisos

### ❌ Script muy lento o se cuelga
- Cerrar programas pesados antes de ejecutar
- Verificar que no hay escaneo de antivirus activo
- Usar `quick_assessment.ps1` en lugar de scripts completos

---

## 📁 Organización de Reportes

Los reportes se guardan automáticamente con este formato:
```
logs_reports/
├── diagnostico_rapido_2024-01-15_14-30-25.html
├── problemas_detectados_2024-01-15_14-35-12.html
├── diagnostico_completo_2024-01-15_14-40-18.html
└── inventario_2024-01-15_14-45-30.html
```

**Tip:** El formato de fecha permite ordenar cronológicamente y hacer seguimiento de múltiples visitas al mismo cliente.

---

## 📞 Frases Útiles para Clientes

### Al explicar qué estás haciendo:
- *"Voy a ejecutar un diagnóstico rápido para ver el estado general"*
- *"Este script busca automáticamente los problemas más comunes"*
- *"Voy a generar un reporte completo que le voy a entregar"*

### Al entregar reportes:
- *"Este reporte muestra todo lo que encontré en su equipo"*
- *"Las secciones en rojo necesitan atención inmediata"*
- *"Las amarillas son recomendaciones para el futuro"*
- *"Puede guardar este reporte para futuras referencias"*

---

**Desarrollado por técnicos, para técnicos** 🛠️