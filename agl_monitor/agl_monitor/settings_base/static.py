from pathlib import Path
import os

# Static files (CSS, JavaScript, Images)
# https://docs.djangoproject.com/en/5.0/howto/static-files/



BASE_DIR = os.environ.get("SERVICE_BASE_DIR", Path(__file__).resolve().parent.parent)
BASE_DIR = Path(BASE_DIR).resolve()


# Print Base dir to Console
print(f"BASE_DIR: {BASE_DIR}")

STATIC_URL = '/static/'

STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')

STORAGES = {
    "staticfiles": {
        "BACKEND": "whitenoise.storage.CompressedManifestStaticFilesStorage",
    },
}
