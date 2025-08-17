# IT-Support-Scripts
🛠️ **Herramientas profesionales de diagnóstico para técnicos de soporte IT**

Conjunto de scripts PowerShell diseñados específicamente para facilitar el trabajo diario de técnicos de soporte, con diagnósticos automatizados y reportes profesionales para clientes.

---

## 🚀 **INICIO RÁPIDO PARA TÉCNICOS**

### 📋 **¿Qué problema tiene el equipo? Elige tu herramienta:**

| **Situación** | **Script Recomendado** | **Uso** |
|---------------|------------------------|---------|
| 🔍 **Primera revisión del equipo** | `quick_assessment.ps1` | Evaluación inicial rápida |
| 🚨 **El equipo está muy lento** | `problem_detector.ps1` | Encuentra problemas automáticamente |
| 📊 **Necesito un reporte completo** | `diagnostico_completo.ps1` | Análisis exhaustivo para clientes |
| 🌐 **Problemas de internet/red** | `diagnostico_red.ps1` | Diagnóstico específico de conectividad |
| 💾 **El equipo se queda sin memoria** | `diagnostico_rendimiento.ps1` | Análisis de CPU, RAM y procesos |

### 🎯 **MÉTODOS DE EJECUCIÓN (del más fácil al más técnico):**

1. **📁 Doble clic en `ejecutar_master.bat`** ← **MÁS FÁCIL**
   - Menú interactivo con todas las opciones
   - Maneja automáticamente problemas de permisos
   - Ideal para técnicos que prefieren interfaces gráficas

2. **💻 Ejecutar scripts individuales:**
   ```powershell
   # Para diagnóstico rápido (recomendado para primera visita)
   .\quick_assessment.ps1
   
   # Para detectar problemas automáticamente
   .\problem_detector.ps1
   
   # Para reporte completo al cliente
   .\diagnostico_completo.ps1
   ```

3. **🔧 Si hay problemas de permisos:**
   - Clic derecho en PowerShell → "Ejecutar como administrador"
   - Navegar a la carpeta y ejecutar el script deseado

> 💡 **Tip para técnicos:** Todos los reportes se guardan automáticamente en la carpeta `logs_reports` con fecha y hora para fácil seguimiento.

## 🔧 **HERRAMIENTAS PRINCIPALES PARA TÉCNICOS**

### 🏃‍♂️ **Scripts de Diagnóstico Rápido**
> Ideales para visitas técnicas y primera evaluación

**1. `quick_assessment.ps1` - Evaluación Express (2-3 min)**
- ✅ **Para qué:** Primera revisión de cualquier equipo
- 🎯 **Detecta:** CPU alto, poca memoria, problemas de red básicos
- 📄 **Resultado:** Reporte simple con estado general del sistema
- 💼 **Ideal para:** Visitas rápidas, evaluación antes de presupuesto

**2. `problem_detector.ps1` - Detective Automático (3-5 min)**
- ✅ **Para qué:** Cuando el cliente dice "la computadora está lenta"
- 🎯 **Detecta:** Disco lleno, memoria agotada, procesos problemáticos, servicios detenidos
- 📄 **Resultado:** Lista clara de problemas encontrados con prioridades
- 💼 **Ideal para:** Diagnóstico inicial, encontrar la causa de lentitud

### 📊 **Scripts de Reporte Completo**
> Para entregar al cliente o documentar el servicio

**3. `diagnostico_completo.ps1` - Reporte Profesional (5-10 min)**
- ✅ **Para qué:** Generar reporte completo para el cliente
- 🎯 **Incluye:** Inventario de hardware, software, rendimiento, seguridad, red
- 📄 **Resultado:** Reporte HTML profesional con gráficos y recomendaciones
- 💼 **Ideal para:** Entrega al cliente, documentación del servicio

### 🌐 **Scripts Especializados**
> Para problemas específicos

**4. `diagnostico_red.ps1` - Problemas de Internet (2-4 min)**
- ✅ **Para qué:** "No me funciona internet" / "La red va lenta"
- 🎯 **Verifica:** Configuración IP, DNS, conectividad, velocidad
- 📄 **Resultado:** Diagnóstico completo de conectividad
- 💼 **Ideal para:** Problemas de conectividad, configuración de red

**5. `diagnostico_rendimiento.ps1` - Análisis de Lentitud (3-5 min)**
- ✅ **Para qué:** "La computadora va muy lenta"
- 🎯 **Analiza:** Uso de CPU, memoria RAM, procesos pesados, disco
- 📄 **Resultado:** Identificación de procesos problemáticos
- 💼 **Ideal para:** Optimización de rendimiento, limpieza de sistema

## 🛠️ **HERRAMIENTAS DE MANTENIMIENTO**

### 🔄 **Scripts de Mantenimiento Preventivo**

**6. `limpieza_mantenimiento.ps1` - Limpieza Automática**
- ✅ **Para qué:** Mantenimiento preventivo del sistema
- 🎯 **Limpia:** Archivos temporales, cache, logs antiguos
- 💼 **Cuándo usar:** Mantenimiento programado, antes de entregar equipo

**7. `backups.ps1` - Sistema de Respaldo**
- ✅ **Para qué:** Proteger datos importantes antes de cambios
- 🎯 **Respalda:** Documentos, configuraciones, datos críticos
- 💼 **Cuándo usar:** Antes de formatear, reinstalar SO, cambios importantes

**8. `recuperacion_archivos.ps1` - Recuperación de Datos**
- ✅ **Para qué:** "Se me borraron archivos importantes"
- 🎯 **Recupera:** Archivos eliminados, papelera, temporales
- 💼 **Cuándo usar:** Recuperación de datos, archivos eliminados accidentalmente

### 🔒 **Scripts de Seguridad e Inventario**

**9. `escaneo_seguridad.ps1` - Verificación de Seguridad**
- ✅ **Para qué:** Verificar estado de seguridad del equipo
- 🎯 **Verifica:** Antivirus, firewall, actualizaciones, vulnerabilidades
- 💼 **Cuándo usar:** Auditoría de seguridad, después de infección

**10. `inventario_hw_sw.ps1` - Inventario Completo**
- ✅ **Para qué:** Documentar hardware y software instalado
- 🎯 **Lista:** Componentes, programas, versiones, licencias
- 💼 **Cuándo usar:** Inventario de empresa, valoración de equipo

**11. `validacion_usuario.ps1` - Configuración de Usuario**
- ✅ **Para qué:** Verificar perfiles y permisos de usuario
- 🎯 **Verifica:** Cuentas, permisos, configuraciones, políticas
- 💼 **Cuándo usar:** Problemas de acceso, configuración de nuevos usuarios

---

## 📁 **DÓNDE ENCONTRAR LOS REPORTES**

Todos los scripts guardan automáticamente sus resultados en:
```
📂 logs_reports/
├── diagnostico_rapido_2024-01-15_14-30-25.html
├── problemas_detectados_2024-01-15_14-35-12.html
├── diagnostico_completo_2024-01-15_14-40-18.html
└── ...
```

💡 **Tip:** Los archivos incluyen fecha y hora para fácil identificación y seguimiento.

## 🎯 **CASOS DE USO PARA TÉCNICOS DE SOPORTE**

### 📞 **Escenarios Típicos de Llamadas de Soporte**

| **El cliente dice...** | **Script recomendado** | **Qué hacer después** |
|------------------------|-------------------------|----------------------|
| *"La computadora está muy lenta"* | `problem_detector.ps1` | Revisar procesos problemáticos y memoria |
| *"No me funciona internet"* | `diagnostico_red.ps1` | Verificar configuración y conectividad |
| *"Se me borraron archivos"* | `recuperacion_archivos.ps1` | Buscar en papelera y temporales |
| *"Necesito un reporte del equipo"* | `diagnostico_completo.ps1` | Entregar reporte HTML al cliente |
| *"¿Qué programas tengo instalados?"* | `inventario_hw_sw.ps1` | Generar listado completo |

### 🏢 **Flujo de Trabajo Recomendado para Visitas Técnicas**

#### **1. Llegada al Cliente (Primeros 5 minutos)**
```
1. Ejecutar quick_assessment.ps1
   └─ Evaluación inicial del estado general

2. Si hay problemas evidentes:
   └─ Ejecutar problem_detector.ps1
   └─ Identificar causa raíz
```

#### **2. Diagnóstico Detallado (10-15 minutos)**
```
3. Según el problema detectado:
   ├─ Lentitud → diagnostico_rendimiento.ps1
   ├─ Red → diagnostico_red.ps1
   ├─ Seguridad → escaneo_seguridad.ps1
   └─ General → diagnostico_completo.ps1
```

#### **3. Antes de Hacer Cambios**
```
4. Protección de datos:
   └─ Ejecutar backups.ps1 (archivos importantes)

5. Documentar estado inicial:
   └─ Guardar reportes para comparación posterior
```

#### **4. Al Finalizar el Servicio**
```
6. Verificación final:
   └─ Ejecutar quick_assessment.ps1 (confirmar mejoras)

7. Entrega al cliente:
   └─ Mostrar reporte de diagnostico_completo.ps1
   └─ Explicar cambios realizados
```

---

## ⚙️ **REQUISITOS Y CONFIGURACIÓN**

### 💻 **Requisitos del Sistema**
- **Windows:** 10, 11, Server 2016+
- **PowerShell:** Versión 5.1 o superior (incluido en Windows)
- **Permisos:** Usuario normal (Administrador recomendado para funcionalidad completa)
- **Espacio:** ~50MB para reportes y logs

### 🔧 **Configuración Rápida**
1. Descargar y extraer en una carpeta (ej: `C:\ITTools\`)
2. **¡Listo!** No requiere instalación adicional
3. Todos los scripts funcionan desde la misma carpeta
4. Los reportes se guardan automáticamente en `logs_reports\`

### 🛡️ **Manejo de Políticas de Ejecución**
Los scripts se configuran automáticamente, pero si hay problemas:

```powershell
# Método 1: Configuración temporal (recomendado)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Método 2: Para el usuario actual
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

## 🆘 **SOLUCIÓN DE PROBLEMAS COMUNES**

### ❌ **"No puedo ejecutar los scripts"**
**Síntomas:** Error de políticas de ejecución, scripts no se ejecutan

**Soluciones:**
1. **Método más fácil:** Usar `ejecutar_master.bat` (doble clic)
2. **PowerShell como Admin:**
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
3. **Ejecución temporal:**
   ```powershell
   powershell -ExecutionPolicy Bypass .\quick_assessment.ps1
   ```

### ❌ **"Los reportes no se generan"**
**Síntomas:** Scripts ejecutan pero no aparecen reportes HTML

**Soluciones:**
1. Verificar que existe la carpeta `logs_reports\`
2. Ejecutar como administrador
3. Verificar permisos de escritura en la carpeta

### ❌ **"El diagnóstico de red falla"**
**Síntomas:** No detecta adaptadores o falla conectividad

**Soluciones:**
1. Verificar que hay adaptadores de red activos
2. Ejecutar como administrador
3. Verificar que Windows Firewall permite ping

### ❌ **"Scripts van muy lentos"**
**Síntomas:** Los diagnósticos tardan mucho tiempo

**Soluciones:**
1. Cerrar programas innecesarios antes de ejecutar
2. Usar `quick_assessment.ps1` para diagnósticos rápidos
3. Verificar que el antivirus no esté escaneando los scripts

---

## 📞 **SOPORTE Y AYUDA**

### 🛠️ **Para Técnicos de Soporte**
- **GitHub Issues:** [Reportar problemas o sugerir mejoras](../../issues)
- **Documentación:** Ver archivos de ejemplo en `logs_reports\`
- **Comunidad:** Compartir experiencias en Issues

### 📚 **Recursos Adicionales**
- **Ejemplos de reportes:** En la carpeta `logs_reports\` después de ejecutar
- **Logs detallados:** Cada script genera logs de errores si algo falla
- **Códigos de error:** Revisar archivo `ErrorHandler.ps1` para detalles

---

## 📄 **LICENCIA**

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para detalles.

**⭐ Si este proyecto te ha sido útil como técnico de soporte, ¡no olvides darle una estrella!**

---

*Desarrollado por y para técnicos de soporte IT* 🛠️
