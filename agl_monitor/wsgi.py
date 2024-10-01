"""
WSGI config for agl_monitor project.

It exposes the WSGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.1/howto/deployment/wsgi/
"""

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'agl_monitor.settings_prod')

# always set DJANGO_SETTINGS_MODULE to the correct settings file

application = get_wsgi_application()
