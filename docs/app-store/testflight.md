# publicación y testflight — 1.0

## estado

código preparado para versión 1.0, build 1. no está publicado ni subido a testflight. no se ha firmado, instalado ni probado este build en un reloj real. no ejecutar simuladores.

## preparar

1. activar la membresía apple developer; revisar contratos y registrar `com.kisnner26.girasol` y `com.kisnner26.girasol.widgets`. configurar healthkit y el grupo compartido de llavero `$(AppIdentifierPrefix)com.kisnner26.shared` en perfiles de distribución.
2. ejecutar `xcodegen generate`, `swift test` y `python3 scripts/validate-release.py`.
3. compilar: `xcodebuild -project Girasol.xcodeproj -scheme Girasol -configuration Release -destination 'generic/platform=watchOS' CODE_SIGNING_ALLOWED=NO build`.
4. con la cuenta y firma configuradas por el propietario, seleccionar el destino genérico de watchos en xcode y usar product > archive. validar el archivo en organizer y generar el informe de privacidad. comprobar los dos manifiestos dentro de los bundles. no usar el build sin firma para subir.
5. crear la ficha watchos en app store connect, versión 1.0. pegar los textos es/en, añadir soporte y política en urls https públicas, completar privacidad, cifrado, disponibilidad, situación de comerciante y clasificación por edades. las respuestas de exportación dependen del binario final: el código actual usa https y llavero del sistema, pero no se ha presentado una declaración.
6. subir desde organizer. resolver cualquier validación de apple. incrementar `CURRENT_PROJECT_VERSION` en ambos targets para cada nuevo upload. confirmar que la versión de xcode/sdk instalada es admitida por connect; haber compilado con xcode beta no lo demuestra.
7. en testflight, completar información de prueba, contacto y notas. añadir primero testers internos elegibles; para externos, crear grupo y presentar a beta app review cuando se solicite. instalar desde testflight con el iphone enlazado al ultra 2.
8. documentar cada prueba real abajo y capturar es/en. publicar manualmente tras revisión de apple; no programar publicación automática sin decisión del propietario.

## matriz de aceptación en ultra 2

- instalación limpia, primera apertura y selección es/en; permitir y denegar Salud, ubicación y notificaciones por separado. no confundir consulta vacía de Salud con autorización denegada.
- registrar y deshacer agua/comida; comprobar cantidades en Salud. respiración completa e interrumpida, sin entrenamientos creados por juegos.
- cada juego: empezar, atenuar pantalla, cubrirla, pulsar corona, regresar, continuar y salir. repetir durante calibración y con un dardo en vuelo. verificar ausencia de audio de fondo y sensores tras salir. probar modo táctil y gesto.
- complicaciones en todos los formatos: uv cero real, pronóstico vigente, caducado, sin datos y sin red. revisar el cambio de día y la actualización tras volver a abrir.
- exposición: leer unidad sed, aviso de estimación parcial y fuentes; cambiar protector no reduce la estimación.
- revisar sueño vacío, cuerpo sin oxígeno, textos largos y todos los textos nuevos con el tamaño de letra habitual. el soporte completo de dynamic type/voiceover sigue siendo fase 2 y no debe anunciarse como validado.
- verificar que nunca aparece autenticación game center. revisar política sin conexión y enlaces con conexión.
- comparar consumo durante una sesión de juego y otra de respiración con una referencia de igual duración. anotar temperatura, batería inicial/final y estado de pantalla; todavía no hay mediciones.

## game center: preparado, desactivado

el código está condicionado a `GIRASOL_GAME_CENTER`, que no se define en `project.yml`. no activar en 1.0 por accidente. para una versión posterior: configurar capability y perfiles con cuenta de pago, crear tablas `girasol.pistol`, `girasol.darts`, `girasol.tennis`, `girasol.airbasketball`, definir la condición de compilación, revisar privacidad y probar autenticación/envío en el reloj. conservar código no significa que esa ruta ya esté validada.

## enlaces oficiales

- [testflight](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview)
- [subir builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds)
- [requisitos de envío](https://developer.apple.com/news/upcoming-requirements/)
- [capturas](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [guía de revisión](https://developer.apple.com/app-store/review/guidelines/)
