deflink &name
deflink &wire
deflink &regcontainer
deflink &regleaf

deffunctionlink λhandler
deffunctionlink λreset
deffunctionlink λinstantiate
deffunctionlink λinstall

defqueuelink &inq
defqueuelink &outq

def3bytes StringIndex
defbytesymbol Dir [down | up | across | through]

defbyte SenderIX
defbyte SenderPortIX
defbyte ReceiverIX
defbyte ReceiverPortIX

defstruct name {
  StringIndex
  &name
}

defstruct wire {
  Dir
  SenderIX        "sender"
  SenderPortIX    "senderport"
  ReceiverIX      "receiver"
  ReceiverPortIX  "receiverport"
  &wire
}

defstruct container-template <: collectable {
  StringIndex "name"
  &Template
}
defstruct leaf-template <: collectable {
  StringIndex "name"
  λhandler
  λreset
  λinstantiate
  λinstall
}

defcollection creg of container-template
defcollection lreg of leaf-template
defobj registry {
  creg
  lreg
}

defobj ėleaf {
  &inq
  &outq
  λhandler
  λreset
  λinstantiate
  λinstall
}

defobj ėcontainer {
  &inq
  &outq
  λhandler
  λreset
  λinstantiate
  λinstall
  Children
  Wires
}

deflink ė ≡ [containeė | leafė]


defproc conditional-deliver {
  # deliver the mevent to the receiver specified in the wire if the source matches the sender in the wire
  <( source mev wire )
  mev.port -> outport
  mev.payload -> payload
  wire.dir -> dir
  wire.sender -> sender
  wire.sender-port -> sender-port
  wire.receiver -> receiver
  wire.receiver-port -> receiver-port
  %if %and ((sender == source) (sender-port == outport)) {
    new-mevent <- %fresh-mevent
    receiver-port -> new-mevent.port
    payload -> new-mevent.payload
    %symbolic-cond dir {
      %case down:    { @receiver.enqueue-input new-mevent }
      %case up:      { @receiver.enqueue-output new-mevent }
      %case across:  { @receiver.enqueue-input new-mevent }
      %case through: { @receiver.enqueue-output new-mevent }
    }
}

defproc deliver-atomically {
  # loop through all wires of the given part, atomically, and fire each wire
  <( container source mev )
  %loop over container.wires -> wire {
    >( wire mev source ) @conditional-deliver
  }
}

defproc register-container {
  <( name inports outports children wires )
}

defproc register-leaf {
  <( name inports outports handler reset instantiator installer )
}


### Instantiation of parts

defproc instantiate-part {
  # find name in the registry, make an instance, leave the instance on top of the stack
  <( name )
  containers <- reg.creg
  %traverse containers -> c {
    %if c.name == name {
      >c.Template @instantiate-container
      %done
    }
  }

  leaves <- reg.lreg
  %traverse leaves -> l {
    %if l.name == name {
      >( l.handler l.reset l.instantiate l.install) @instantiate-leaf
      %done
    }
  }

  %error "part ${name} not found"
}

defproc instantiate-container {
}

defproc instantiate-leaf {
}