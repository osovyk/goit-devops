from django.contrib import admin
from django.urls import path
from django.http import HttpResponse


def index(request):
    return HttpResponse("<h1>Django + PostgreSQL + Nginx</h1><p>The app is running!</p>")


urlpatterns = [
    path('admin/', admin.site.urls),
    path('', index),
]
