Quantum = RegisterMod("Quantum Pack", 1)

Quantum.save = include("save_manager")
Quantum.save.Init(Quantum)

Quantum.UTILS = include("quantum.utils")
Quantum.QUEUE = include("quantum.sys_queue")

include("quantum.item_pickupreroll")
include("quantum.item_removeoptions")
include("quantum.item_hydrokinesis")
include("quantum.item_horserpills")
include("quantum.item_cultfollowing")
include("quantum.item_enemylink")
include("quantum.item_fryingpan")