# app privacy y permisos — 1.0

revisión de código y fuentes: 26 de octubre de 2026. no se han enviado respuestas a app store connect.

## respuestas propuestas

- recopilación: sí, por el proveedor meteorológico. no seleccionar «datos no recopilados».
- seguimiento: no. sin anuncios, idfa ni dominios de tracking.
- ubicación aproximada: función de la app (pronóstico). coordenadas con dos decimales, no ubicación precisa.
- otros datos de diagnóstico: función de la app (registros técnicos con ip para diagnóstico y prevención de abuso de open-meteo).
- vinculación: sí, criterio conservador para ambas categorías. no hay cuenta de girasol, pero no se ha acreditado desidentificación antes de guardar coordenadas e ip juntas. la afirmación del proveedor de no asociar identidades no demuestra por sí sola los requisitos de apple para «no vinculados».
- salud, fitness, perfil y partidas: solo procesamiento local/healthkit; no se declaran como recopilados por girasol al no transmitirse fuera del dispositivo a nuestros servicios.
- soporte por correo: opcional y voluntario, fuera del uso principal. revisar la excepción de divulgación opcional de apple; si cambia el flujo de soporte, reevaluar email y contenido de soporte.
- game center: desactivado por compilación en 1.0; antes de activarlo revisar manifiesto, política y ficha.

el manifiesto de la app refleja ubicación aproximada y diagnóstico, vinculados y sin seguimiento. el widget no realiza solicitudes de red. userdefaults usa `CA92.1`: preferencias y caché del contenedor propio; la comunicación entre app y widget usa llavero, no suites de userdefaults.

## permisos mínimos por función

| permiso | necesidad | escritura / transferencia |
|---|---|---|
| healthkit: agua, energía consumida, atención plena | registrar y consultar hábitos | escribe solo acciones del usuario |
| healthkit: luz diurna, energía activa, pasos | exposición estimada y actividad | lectura |
| healthkit: pulso, pulso en reposo, oxígeno | pantalla cuerpo | lectura; no inicia medición de oxígeno |
| healthkit: sueño | resumen nocturno | lectura |
| healthkit: peso, altura, fecha de nacimiento, sexo | perfil y metas orientativas | lectura; editable manualmente |
| ubicación durante el uso | clima y orientación solar | coordenadas a dos decimales al proveedor |
| movimiento | juegos y calibración | procesamiento local |
| notificaciones | recordatorios optativos | locales; no push remoto |

sin permiso de entrenamientos, ubicación permanente, cámara, micrófono, contactos o seguimiento. la solicitud de Salud ocurre por acción del usuario; refrescar el clima no la repite. el refresco en segundo plano no solicita autorización de ubicación. permitir o denegar lecturas de Salud no puede inferirse de consultas vacías.

## fuentes y puntos pendientes

- [apple: app privacy](https://developer.apple.com/app-store/app-privacy-details/): definición de recopilación, ip según uso, datos exclusivamente locales y vinculación.
- [apple: motivos de api](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons): userdefaults `CA92.1`.
- [open-meteo: términos y privacidad](https://open-meteo.com/en/terms): registros técnicos, coordenadas y retención hasta 90 días.

antes de enviar: confirmar que el binario firmado coincide con esta auditoría, generar privacy report en organizer y volver a revisar la política del proveedor. no se ha inspeccionado su infraestructura. publicar las políticas es/en en una url https accesible; los html están preparados en `docs/privacy`, pero no están publicados.
