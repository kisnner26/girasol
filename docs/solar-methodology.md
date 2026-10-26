# estimación solar / solar estimate

revisión: 26 de octubre de 2026.

## español

la app combina el pronóstico uv de open-meteo con minutos de luz diurna registrados en healthkit. no es un dosímetro ni determina la tolerancia de la piel. usa uv interpolado en el centro del intervalo horario: dosis ambiental estimada = uv × 0,025 w/m² × 60 s/min × minutos. 100 j/m² equivalen a 1 sed. los minutos se limitan a la duración de cada intervalo para no multiplicar muestras solapadas.

se retiraron la tabla de tolerancia por fototipo, el multiplicador `spf × 0,5`, los minutos supuestamente seguros y las alertas de límite personal. seleccionar protector ya no reduce exposición pasada. la racha solo usa agua y pasos; los campos solares históricos se conservan para compatibilidad, pero no puntúan.

la aproximación no reconstruye la trayectoria del usuario ni mide sombra, ropa, orientación o aplicación del protector. el pronóstico y los registros de luz pueden estar incompletos. no hay validación clínica de esta estimación individual. una sed no es un límite seguro. no uses el resultado para prolongar la exposición.

## english

girasol combines open-meteo uv forecasts with healthkit time in daylight. it is not a dosimeter and does not determine skin tolerance. estimated ambient exposure = interpolated hourly uv × 0.025 w/m² × 60 s/min × recorded minutes; 100 j/m² equals 1 sed. minutes are capped at the bucket duration.

skin-type thresholds, the `spf × 0.5` multiplier, safe-time predictions and personal-limit alerts have been removed. sunscreen selection cannot reduce past exposure. streaks now depend on water and steps; legacy solar fields remain readable but do not affect goals.

shade, clothing, orientation, sunscreen application, location changes and incomplete data limit this estimate. it is not clinically validated for an individual. one sed is not a safe exposure allowance. do not extend sun exposure based on this number. consult a healthcare professional before making medical decisions.

## fuentes / sources

- [knmi, definición del índice uv](https://temis.pmc.knmi.cloud/uvradiation/product/uvi-uvd.html): relación entre irradiancia eritemática e índice uv.
- [cie, standard erythema dose](https://cie.co.at/publications/standard-erythema-dose-review): 1 sed = 100 j/m² y diferencia frente a respuesta individual.
- [oms, radiación ultravioleta](https://www.who.int/news-room/fact-sheets/detail/ultraviolet-radiation): protección desde uv 3; el protector no debe prolongar la estancia al sol.
- [fda, protector solar](https://www.fda.gov/drugs/understanding-over-counter-medicines/sunscreen-how-help-protect-your-skin-sun): spf no equivale a tiempo adicional al sol.
- [apple, revisión 1.4.1](https://developer.apple.com/app-store/review/guidelines/#physical-harm): metodología, precisión y consejo médico.
