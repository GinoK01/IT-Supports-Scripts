
# IT-Support-Scripts
**Professional diagnostic tools for IT support technicians**

A collection of PowerShell scripts designed specifically to make daily work easier for support technicians, with automated diagnostics and professional reports for clients.

---


## **QUICK START FOR TECHNICIANS**


### **What's wrong with the computer? Choose your tool:**

| **Situation** | **Recommended Script** | **Use** |
|---------------|------------------------|---------|
| **First computer check** | `quick_assessment.ps1` | Quick initial evaluation |
| **Computer is very slow** | `problem_detector.ps1` | Finds problems automatically |
| **Need a complete report** | `diagnostico_completo.ps1` | Full analysis for clients |
| **Internet/network problems** | `diagnostico_red.ps1` | Specific connectivity diagnosis |
| **Computer runs out of memory** | `diagnostico_rendimiento.ps1` | CPU, RAM and process analysis |


### **HOW TO RUN (from easiest to most technical):**

1. **Double-click on `ejecutar_master.bat`** ← **EASIEST**
   - Interactive menu with all options
   - Automatically handles permission problems
   - Great for technicians who prefer visual interfaces

2. **Run individual scripts:**
   ```powershell
   # For quick diagnosis (recommended for first visit)
   .\quick_assessment.ps1
   
   # To detect problems automatically
   .\problem_detector.ps1
   
   # For complete client report
   .\diagnostico_completo.ps1
   ```

3. **If you have permission problems:**
   - Right-click on PowerShell → "Run as administrator"
   - Navigate to the folder and run the desired script


> **Tip for technicians:** All reports are automatically saved in the `logs_reports` folder with date and time for easy tracking.


## **MAIN TOOLS FOR TECHNICIANS**


### **Quick Diagnostic Scripts**
> Perfect for technical visits and first evaluation


**1. `quick_assessment.ps1` - Express Evaluation (2-3 min)**
- **What it does:** First check of any computer
- **Detects:** High CPU, low memory, basic network problems
- **Result:** Simple report with general system status
- **Great for:** Quick visits, evaluation before quotes

**2. `problem_detector.ps1` - Automatic Detective (3-5 min)**
- **What it does:** When the client says "the computer is slow"
- **Detects:** Full disk, exhausted memory, problematic processes, stopped services
- **Result:** Clear list of problems found with priorities
- **Great for:** Initial diagnosis, finding the cause of slowness


### **Complete Report Scripts**
> For delivering to clients or documenting the service


**3. `diagnostico_completo.ps1` - Professional Report (5-10 min)**
- **What it does:** Generate complete report for the client
- **Includes:** Hardware inventory, software, performance, security, network
- **Result:** Professional HTML report with charts and recommendations
- **Great for:** Client delivery, service documentation


### **Specialized Scripts**
> For specific problems


**4. `diagnostico_red.ps1` - Internet Problems (2-4 min)**
- **What it does:** "Internet doesn't work" / "Network is slow"
- **Checks:** IP configuration, DNS, connectivity, speed
- **Result:** Complete connectivity diagnosis
- **Great for:** Connectivity problems, network configuration

**5. `diagnostico_rendimiento.ps1` - Slowness Analysis (3-5 min)**
- **What it does:** "The computer is very slow"
- **Analyzes:** CPU usage, RAM memory, heavy processes, disk
- **Result:** Identification of problematic processes
- **Great for:** Performance optimization, system cleanup


## **MAINTENANCE TOOLS**


### **Preventive Maintenance Scripts**


**6. `limpieza_mantenimiento.ps1` - Automatic Cleanup**
- **What it does:** Preventive system maintenance
- **Cleans:** Temporary files, cache, old logs
- **When to use:** Scheduled maintenance, before delivering computer


**7. `backups.ps1` - Backup System**
- **What it does:** Protect important data before changes
- **Backs up:** Documents, configurations, critical data
- **When to use:** Before formatting, reinstalling OS, important changes


**8. `recuperacion_archivos.ps1` - Data Recovery**
- **What it does:** "My important files got deleted"
- **Recovers:** Deleted files, recycle bin, temporary files
- **When to use:** Data recovery, accidentally deleted files


### **Security and Inventory Scripts**


**9. `escaneo_seguridad.ps1` - Security Check**
- **What it does:** Check computer security status
- **Checks:** Antivirus, firewall, updates, vulnerabilities
- **When to use:** Security audit, after infection


**10. `inventario_hw_sw.ps1` - Complete Inventory**
- **What it does:** Document installed hardware and software
- **Lists:** Components, programs, versions, licenses
- **When to use:** Company inventory, computer valuation


**11. `validacion_usuario.ps1` - User Configuration**
- **What it does:** Check user profiles and permissions
- **Checks:** Accounts, permissions, configurations, policies
- **When to use:** Access problems, setting up new users

---


## **WHERE TO FIND THE REPORTS**

All scripts automatically save their results in:

```
logs_reports/
├── diagnostico_rapido_2024-01-15_14-30-25.html
├── problemas_detectados_2024-01-15_14-35-12.html
├── diagnostico_completo_2024-01-15_14-40-18.html
└── ...
```


**Tip:** Files include date and time for easy identification and tracking.


## **USE CASES FOR SUPPORT TECHNICIANS**


### **Typical Support Call Scenarios**

| **Client says...** | **Recommended Script** | **What to do next** |
|------------------------|-------------------------|----------------------|
| *"The computer is very slow"* | `problem_detector.ps1` | Check problematic processes and memory |
| *"Internet doesn't work"* | `diagnostico_red.ps1` | Check configuration and connectivity |
| *"My files got deleted"* | `recuperacion_archivos.ps1` | Search in recycle bin and temporary files |
| *"I need a computer report"* | `diagnostico_completo.ps1` | Deliver HTML report to client |
| *"What programs do I have installed?"* | `inventario_hw_sw.ps1` | Generate complete list |


---


## **REQUIREMENTS AND SETUP**


### **System Requirements**
- **Windows:** 10, 11, Server 2016+
- **PowerShell:** Version 5.1 or higher (included in Windows)
- **Permissions:** Normal user (Administrator recommended for full functionality)
- **Space:** ~50MB for reports and logs


### **Quick Setup**
1. Download and extract to a folder (e.g., `C:\ITTools\`)
2. **Ready!** No additional installation required
3. All scripts work from the same folder
4. Reports are automatically saved in `logs_reports\`


### **Execution Policy Management**
Scripts configure themselves automatically, but if there are problems:

```powershell
# Method 1: Temporary configuration (recommended)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Method 2: For current user
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```


## **COMMON PROBLEM SOLUTIONS**


### **"I can't run the scripts"**
**Symptoms:** Execution policy error, scripts don't run

**Solutions:**
1. **Easiest method:** Use `ejecutar_master.bat` (double-click)
2. **PowerShell as Admin:**
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
3. **Temporary execution:**
   ```powershell
   powershell -ExecutionPolicy Bypass .\quick_assessment.ps1
   ```


### **"Reports don't generate"**
**Symptoms:** Scripts run but HTML reports don't appear

**Solutions:**
1. Check that the `logs_reports\` folder exists
2. Run as administrator
3. Check write permissions on the folder


### **"Network diagnosis fails"**
**Symptoms:** Doesn't detect adapters or connectivity fails

**Solutions:**
1. Check that there are active network adapters
2. Run as administrator
3. Check that Windows Firewall allows ping


### **"Scripts are very slow"**
**Symptoms:** Diagnostics take a long time

**Solutions:**
1. Close unnecessary programs before running
2. Use `quick_assessment.ps1` for quick diagnostics
3. Check that antivirus isn't scanning the scripts

---


## **SUPPORT AND HELP**


### **For Support Technicians**
- **GitHub Issues:** [Report problems or suggest improvements](../../issues)
- **Documentation:** See example files in `logs_reports\`
- **Community:** Share experiences in Issues


### **Additional Resources**
- **Report examples:** In the `logs_reports\` folder after running
- **Detailed logs:** Each script generates error logs if something fails
- **Error codes:** Check `ErrorHandler.ps1` file for details

---

## 📄 **LICENSE**

This project is under the MIT License - see the [LICENSE](LICENSE) file for details.

**⭐ If this project has been useful to you as a support technician, don't forget to give it a star!**

---


*Developed by and for IT support technicians*
