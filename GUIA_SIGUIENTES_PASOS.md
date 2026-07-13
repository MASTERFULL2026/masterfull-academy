# Guía de siguientes pasos para Masterfull Academy

Esta guía está pensada para trabajar sin Visual Studio Code y sin editar archivos manualmente.

## 1. Ejecutar `schema-final.sql` en Supabase

1. Entra a Supabase.
2. Abre tu proyecto.
3. Ve a **SQL Editor**.
4. Crea una consulta nueva.
5. Copia todo el contenido de `supabase/schema-final.sql`.
6. Pégalo en el editor.
7. Pulsa **Run**.

Este SQL es idempotente: puedes ejecutarlo más de una vez. No borra tablas ni resultados existentes.

## 2. Configurar URLs de autenticación

En Supabase:

1. Ve a **Authentication**.
2. Abre **URL Configuration**.
3. En **Site URL**, coloca la URL final de GitHub Pages:

```text
https://TU-USUARIO.github.io/TU-REPOSITORIO/
```

4. En **Redirect URLs**, agrega esa misma URL.
5. Para pruebas locales, agrega también:

```text
http://localhost:5500/
```

6. Ve a **Authentication > Providers > Email**.
7. Activa el registro por correo.
8. Decide si quieres exigir confirmación por correo. Si está activa, el alumno deberá confirmar su cuenta antes de ingresar.

## 3. Subir el proyecto usando la página web de GitHub

1. Entra a GitHub.
2. Crea un repositorio nuevo.
3. Pulsa **Add file > Upload files**.
4. Sube todos los archivos y carpetas del proyecto:
   - `index.html`
   - `styles.css`
   - `app.js`
   - `config.js`
   - `config.example.js`
   - `README.md`
   - `SECURITY.md`
   - `GUIA_SIGUIENTES_PASOS.md`
   - `data/`
   - `supabase/`
5. Pulsa **Commit changes**.

No subas claves secretas. El archivo `config.js` solo contiene la URL pública del proyecto y la publishable key.

## 4. Activar GitHub Pages

1. En tu repositorio, entra a **Settings**.
2. Abre **Pages**.
3. En **Build and deployment**, elige **Deploy from a branch**.
4. Selecciona la rama `main`.
5. Selecciona la carpeta `/ (root)`.
6. Pulsa **Save**.
7. Espera unos minutos.
8. Copia la URL publicada.
9. Vuelve a Supabase y coloca esa URL en **Site URL** y **Redirect URLs**.

## 5. Crear tu cuenta de profesor

1. Abre la plataforma publicada.
2. Regístrate con tu nombre, correo y contraseña.
3. Por seguridad, el registro público crea una cuenta de alumno.
4. En Supabase, abre **SQL Editor**.
5. Ejecuta:

```sql
update public.profiles
set role = 'teacher'
where email = 'TU-CORREO-DE-PROFESOR';
```

6. Cierra sesión en la plataforma.
7. Vuelve a iniciar sesión.
8. Ya deberías ver el panel del profesor.

## 6. Probar con un alumno

1. Abre la plataforma.
2. Registra una cuenta con otro correo.
3. Inicia sesión como alumno.
4. Verifica que aparezcan los cursos publicados desde `data/catalog.json`.
5. Rinde un examen.
6. Comprueba que se muestre la nota.
7. En Supabase, abre la tabla `public.results` y verifica que se haya guardado el resultado.
8. Inicia sesión como profesor y revisa la tabla de resultados.

## 7. Publicar nuevos exámenes JSON

1. Inicia sesión como profesor.
2. Crea un borrador local de curso o examen.
3. Agrega preguntas manualmente, importa JSON o genera preguntas desde apuntes.
4. Pulsa **Validar JSON**.
5. Pulsa **Exportar examen JSON**.
6. Sube el archivo descargado a la carpeta `data/exams/` del repositorio en GitHub.
7. Edita `data/catalog.json` desde la web de GitHub.
8. Agrega la ruta del examen dentro del curso correspondiente, por ejemplo:

```json
"./data/exams/nuevo-examen.json"
```

9. Haz commit.
10. Espera la actualización de GitHub Pages.
11. Recarga la plataforma.

## 8. Recordatorio de seguridad

Los exámenes JSON publicados en GitHub Pages pueden ser inspeccionados. Esta versión sirve para prácticas, tareas y evaluaciones básicas. Para evaluaciones de alta seguridad, la corrección debe moverse en el futuro a una función segura en Supabase.
