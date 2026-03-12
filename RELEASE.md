# Solar Power Manager - Android Release

## 📦 Installazione

Puoi scaricare gli APK (Android Package) compilati da [GitHub Releases](https://github.com/Fabbro96/solar_power_manager/releases).

### Come installare l'APK su Android

1. **Download**: Scarica dalla [pagina delle release](https://github.com/Fabbro96/solar_power_manager/releases/latest) il file con versione e architettura nel nome, ad esempio `solar-power-manager-1.0.10--build-10-arm64-v8a.apk`

2. **Trasferimento**: Trasferisci il file nel tuo dispositivo Android (tramite USB, Drive cloud, ecc.)

3. **Installazione**: 
   - Apri il file manager del tuo telefono
   - Naviga al file APK scaricato
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

Nuove build verranno pubblicate automaticamente su [GitHub Releases](https://github.com/Fabbro96/solar_power_manager/releases) tramite GitHub Actions: ogni push aggiorna la prerelease `latest-apk`, mentre ogni tag `v*` crea o aggiorna una release versionata con gli APK nel nome corretto.
