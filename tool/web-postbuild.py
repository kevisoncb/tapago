"""Depois de `flutter build web`: dá um nome novo (com hash) à fonte de ícones.

O navegador guarda fontes por nome. Com o nome fixo, quem já abriu o sistema
continua vendo a fonte antiga e os ícones novos ficam em branco. Com o hash no
nome, cada versão publicada força o download da fonte certa.
"""
import hashlib
import json
import os
import sys

build = sys.argv[1] if len(sys.argv) > 1 else "build/web"
fonts = os.path.join(build, "assets", "fonts")
old = os.path.join(fonts, "MaterialIcons-Regular.otf")
data = open(old, "rb").read()
name = "MaterialIcons-%s.otf" % hashlib.sha1(data).hexdigest()[:10]
os.replace(old, os.path.join(fonts, name))

manifest = os.path.join(build, "assets", "FontManifest.json")
text = open(manifest, encoding="utf-8").read()
assert "fonts/MaterialIcons-Regular.otf" in text, "manifesto inesperado"
open(manifest, "w", encoding="utf-8").write(
    text.replace("fonts/MaterialIcons-Regular.otf", "fonts/" + name)
)
print("fonte de icones:", name)
