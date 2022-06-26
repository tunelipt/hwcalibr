"""
# Software para calibração dos sensore

"""


module HWCalibr

include("manualdaq.jl")



using AbstractDAQs
using AbstractActuators
using DAQenvconds
using DAQespmcp
using HDF5
import DataStructures: OrderedDict

# Criar os dispositivos
function daqdevices(daqip="localhost", envip="localhost")
    dev1 = EspMcp("voltage", daqip)
    dev2 = EnvConds("amb", envip)
    dev3 = MDAQ.ManualDAQ("pitot", "Pitot padrão",
                          ["DP", "Tjato", "TBS", "TBU", "Pa"])

    return DeviceSet("meas", (dev1, dev2, dev3))
end

"""
Vamos fazer cada conjunto de 8 de cada vez!
"""
function setdaqchans(devs, iset=1)
    
    iset = collect( (iset-1)*8 .+ (1:8) )
    daqaddinput(devs[1], iset)
end

    
function testconfig(devs) # Lets measure 5s
    daqconfigdev(devs[1], avg=100, period=100, fps=50)
    daqconfigdev(devs[2], time=5)
end

function calconfig(devs) # Lets measure 5s
    daqdevconfig(devs[1], avg=100, period=100, fps=400)
    daqdevconfig(devs[2], time=40)
end


const calvel = [0.0, 0.5, 1.0, 2.0, 3.0, 5.0, 7.0, 9.0, 12.0, 15.0, 18.0]



function calcontrol(vel, nreps=3)

    ventilador = ManualActuator("ventilador", "vel", 0.0, minval=0.0, maxval=20.1, nsec=10)
    rep = ManualActuator("repeat", "iter", 0.0)

    control = ActuatorSet("control", (ventilador, rep))

    velpts = ExperimentMatrix(vel=vel)
    iterpts = ExperimentMatrix(iter=1:nreps)

    pts = ExperimentMatrixProduct((velpts, iterpts))

    return pts, control

end


function hwcalibr(fname, devs, control, pts; istart=1)
    if isfile(fname)
        if istart==1
            error("$fname existe. Não vou sobreescrever. Decida o que você deseja fazer e tente de novo!")
        end
        println("Começando a partir do ponto $istart")
    else
        h5open(fname, "w") do h
            println("Armazenando a configuração...")# Save configuration
            gconf = create_group(h, "config")
            gdevs = create_group(gconf, "devices")
            gact  = create_group(gconf, "actuators")
            gpts  = create_group(gconf, "points")
            
            savedaqconfig(gdevs, devs)
            saveactuatorconfig(gact, control)
            saveexperimentmatrix(gpts, pts)
            
            gdata = create_group(h, "data")
            matpts = experimentpoints(pts)
            
            attributes(gdata)["points"] = matpts
            attributes(gdata)["params"] = matrixparams(pts)
        end
    end
    
    print("Pressione ENTER para continuar...")
    readline()
    
    restartpoints!(pts)
    i = istart-1
    while movenext!(control, pts)
        h5open(fname, "cw") do h
            i = i + 1  # Index
            println("===================================")
            println("= Ponto $i")
            
            data = daqacquire(devs)
            gdata = h["data"]
            gpoint = create_group(gdata, string(i))
            attributes(gpoint)["point"] = testpoint(pts,i)
            attributes(gpoint)["params"] = matrixparams(pts)
            savedaqdata(gpoint, data)
            println("___________________________________")
            println("\n\n\n\n")
        end
        
    end
    
    
end

    

end

