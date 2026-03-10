# Solar Power Manager - Android Release

## 📦 Installazione

Puoi scaricare l'APK (Android Package) compilato da [GitHub Releases](https://github.com/Fabbro96/solar_power_manager/releases).

### Come installare l'APK su Android

1. **Download**: Scarica il file `app-release.apk` dalla [pagina delle release](https://github.com/Fabbro96/solar_power_manager/releases/latest)

2. **Trasferimento**: Trasferisci il file nel tuo dispositivo Android (tramite USB, Drive cloud, ecc.)

3. **Installazione**: 
   - Apri il file manager del tuo telefono
   - Naviga al file `app-release.apk`
   - Tocca il file e conferma l'installazione
   - Potrebbe essere necessario attivare "Installa app da fonti sconosciute" nelle impostazioni di sicurezza

4. **Primo avvio**:
   - L'app si aprirà automaticamente dopo l'installazione
   - Verifica le impostazioni di rete (assicurati di poter raggiungere l'inverter solare in LAN)
   - Configura l'URL dell'inverter e le credenziali nelle impostazioni app (se presente)

## 🔧 Configurazione

L'app è preconfigurata per connettersi a:
- **URL**: `http://192.168.1.16/monitor.htm`
- **Username**: `admin`
- **Password**: `admin`

Se il tuo inverter ha un IP diverso, dovrai ricompilare l'app modificando `lib/config/app_config.dart`.

## 📊 Build Info

- **Flutter SDK**: `3.6.0+`
- **Build Type**: Release (ottimizzato)
- **Targeting**: Android 5.0+ (API Level 21+)

## 🚀 Aggiornamenti Futuri

Nuove release verranno pubblicate automaticamente su [GitHub Releases](https://github.com/Fabbro96/solar_power_manager/releases) tramite GitHub Actions quando verranno creati nuovi tag git.
