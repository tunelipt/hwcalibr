"""
# Software para calibração dos sensore

"""

module MDAQ

using AbstractDAQs
using AbstractActuators
using DAQenvconds
using DAQespmcp
import DataStructures: OrderedDict
import Dates: now
mutable struct ManualDAQ <: AbstractDAQ
    devname::String
    header::String
    values::Vector{Float64}
    parameters::Vector{String}
    chanidx::OrderedDict{String,Int}
    conf::DAQConfig
    task::DAQTask
end

function ManualDAQ(devname, header, params)

    np = length(params)
    chanidx = Dict
    parameters = fill("", np)
    chanidx = OrderedDict{String,Int}()
   
    for (i,p) in enumerate(params)
        chanidx[p] = i
        parameters[i] = p
    end

    values = zeros(np)
    conf = DAQConfig(devname=devname)
    ManualDAQ(devname, header, values, parameters, chanidx, conf, DAQTask())
end

devtype(dev::ManualDAQ) = "ManualDAQ"

function read_single_parameter(param, ntries=3, default=0.0)

    for i in 1:ntries
        print("$param: ")
        try
            val = parse(Float64, readline())
            return val
        catch e
            println("Valor ilegal. Entre com um número!")
        end
    end
    return default
            
end

function read_user_values(dev::ManualDAQ)
    println("")
    header = dev.header
    nc = length(header)

    np = length(dev.parameters)
    vals = zeros(np)
    
    println("="^(nc+4))
    println("= $header =")
    println("="^(nc+4))
    dev.task.isreading = true
    dev.task.nread = 0
    while true
        println("\nEntre com os parâmetros:")
        for (i,p) in enumerate(dev.parameters)
            vals[i] = read_single_parameter(p)
        end

        println("+++++++++++++++")
        for (i,p) in enumerate(dev.parameters)
            println("$p = $(vals[i])")
        end
        println("+++++++++++++++")
        
        println("\nSe os valores estão corretos, pressione ENTER.")
        print("Se quiser modificar digite algo e pressione ENTER.")
        s = readline()
        if length(s) == 0
            break
        end
    end
    dev.task.nread = 1
    
    for i in 1:np
        dev.values[i] = vals[i]
    end
    dev.task.isreading = false
    println("_"^(nc+4))
end

function AbstractDAQs.daqacquire(dev::ManualDAQ)

    t1 = now()
    read_user_values(dev)
    np  = length(dev.parameters)
    vals = zeros(np, 1)
    for i in 1:np
        vals[i,1] = dev.values[i]
    end
    return MeasData{Matrix{Float64}}(devname(dev), devtype(dev),
                                     t1, 1.0, vals, dev.chanidx)
end

AbstractDAQs.daqchannels(dev::ManualDAQ) = dev.parameters
AbstractDAQs.numchannels(dev::ManualDAQ) = length(dev.parameters)


AbstractDAQs.isreading(dev::ManualDAQ) = dev.task.isreading
AbstractDAQs.samplesread(dev::ManualDAQ) = dev.task.isreading

function AbstractDAQs.daqstart(dev::ManualDAQ)
    if isreading(dev.task)
        error("Already reading...")
    end
    cleartask!(dev.task)
    dev.task.isreading = true
    dev.task.time = now()
    tsk = @async read_user_values(dev)
    dev.task.task = tsk
    return tsk
end

function AbstractDAQs.daqread(dev::ManualDAQ)
    if dev.task.isreading
        wait(dev.task.task)
    end
    
    np  = length(dev.parameters)
    vals = zeros(np, 1)
    for i in 1:np
        vals[i,1] = dev.values[i]
    end
    return MeasData{Matrix{Float64}}(devname(dev), devtype(dev),
                                     dev.task.time, 1.0, vals, dev.chanidx)
    
end


end
