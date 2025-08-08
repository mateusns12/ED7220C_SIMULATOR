-- MAIN

local sim = require('sim')
require(sim.getObject("/gui"))

function sysCall_init()
    -- Inicializacao da Cena
    -- 'robot' criado em GUI
    -- Configure os objetos que podem ser manipulados pelo robo simulado
    robot:detectableObject("/Rob_ManipSphere")
end

function sysCall_cleanup()
    -- Retorna os objetos a posicao inicial
    robot:resetObjects()
end

function sysCall_actuation()
    -- Executa as threads do Controlador. 
    -- Adicione uma nova thread aqui, ou use sysCall_thread

    Runtime.resume(main_coro)
    Runtime.resume(grip_coro)
end