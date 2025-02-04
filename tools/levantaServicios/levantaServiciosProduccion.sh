#! /bin/bash

cd /home/enciclovida/buscador/
export RAILS_ENV=production
$(which redis-server) &
sleep 10
rails runner "eval(File.read '$(pwd)/tools/levantaServicios/levantaBlurrily.rb')" &
nohup ruby $(pwd)/bin/delayed_job -i validaciones --queue=validaciones run > log/delayed_validaciones.log &
nohup ruby $(pwd)/bin/delayed_job -i descargar_taxa --queue=descargar_taxa run > log/delayed_descargas.log &
nohup ruby $(pwd)/bin/delayed_job -i estadisticas --queue=estadisticas run > log/delayed_estadisticas.log &
nohup ruby $(pwd)/bin/delayed_job -i redis --queue=redis run > log/delayed_redis.log &
nohup ruby $(pwd)/bin/delayed_job -i peces --queue=peces run > log/delayed_peces.log &
# Los siguientes delayed job aún no se ocupan pero no se borran hasta que quede listo el módulo de estadísticas
# nohup ruby $(pwd)/bin/delayed_job -i estadisticas_naturalista --queue=estadisticas_naturalista run &
# nohup ruby $(pwd)/bin/delayed_job -i estadisticas_conabio --queue=estadisticas_conabio run &
# nohup ruby $(pwd)/bin/delayed_job -i estadisticas_wikipedia --queue=estadisticas_wikipedia run &
# nohup ruby $(pwd)/bin/delayed_job -i estadisticas_eol --queue=estadisticas_eol run &
# nohup ruby $(pwd)/bin/delayed_job -i estadisticas_tropicos_service --queue=estadisticas_tropicos_service run &
# nohup ruby $(pwd)/bin/delayed_job -i estadisticas_maccaulay --queue=estadisticas_maccaulay run &
# nohup ruby $(pwd)/bin/delayed_job -i estadisticas_SNIB --queue=estadisticas_SNIB run &
# nohup ruby $(pwd)/bin/delayed_job -i estadisticas_mapas_distribucion --queue=estadisticas_mapas_distribucion run &
