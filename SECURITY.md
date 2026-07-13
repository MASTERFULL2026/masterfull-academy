# Seguridad de esta versión

Esta primera versión usa GitHub Pages para publicar archivos estáticos. Eso significa que los archivos JSON de `data/` pueden ser inspeccionados por cualquier persona que tenga acceso al sitio.

Las respuestas correctas permanecen dentro de los JSON para que el navegador pueda calcular la nota. Un alumno con conocimientos técnicos podría encontrar esas respuestas revisando los archivos publicados.

Esta versión sirve para prácticas, tareas y evaluaciones básicas. No debe presentarse como un sistema antifraude ni como una plataforma de exámenes de alta seguridad.

Para evaluaciones de alta seguridad, la calificación debe moverse en el futuro a una Supabase Edge Function o a una función PostgreSQL segura. Nunca se debe esconder una respuesta en JavaScript y afirmar que está protegida.
