source sh/shared.sh

if ! java -v; then
  print "Java not found!"
fi;

print "Downloading plantuml"
curl -LO https://github.com/plantuml/plantuml/releases/download/v1.2025.4/plantuml-mit-1.2025.4.jar

print "Starting server"
java -jar ./plantuml-mit-1.2025.4.jar -picoweb:8080:127.0.0.1 &
echo $!
