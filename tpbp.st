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

defcollection Children of StringIndex
defcollection Wires of wire
defstruct container-template <: collectable {
  StringIndex "name"
  Children
  Wires
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
  high-priority
  λhandler
  λreset
}

defobj ėcontainer {
  &inq
  &outq
  high-priority
  ready-list
  λhandler
  λreset
  Children
  Wires
}

deflink ė ≡ [ėcontainer | ėleaf]


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
    >receiver @append-to-ready-list-of-container
}

defproc deliver-atomically {
  # loop through all wires of the given part, atomically, and fire each wire
  <( container source mev )
  %with-container container {
    %loop over container.wires -> wire {
      >( wire mev source ) @conditional-deliver
    }
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
      >(c.Children c.Wires) @instantiate-container
      %done
    }
  }

  leaves <- reg.lreg
  %traverse leaves -> l {
    %if l.name == name {
      >( l.handler l.reset ) @instantiate-leaf
      %done
    }
  }

  %error "part ${name} not found"
}

defproc instantiate-container {
  c <- %fresh-ėcontainer
  c.inq <- %fresh-queue
  c.outq <- $fresh-queue
  c.handler <- &'container-handler
  c.reset   <- &'container-reset
  c.Wires <- %pop
  c.Children <- %pop
  c.high-priority <- %false
  c.ready-list <- %fresh-ready-list
  >c
}

defproc instantiate-leaf {
  l <- %fresh-ėleaf
  l.inq <- %fresh-queue
  l.outq <- $fresh-queue
  l.reset <- %pop
  l.handler <- %pop
  >l
}

###

defproc container-handler (self) {
  ⋅ handle incoming mevent for a composite part (a "container")
    ⋅⋅ $with-container (self)
      ⋅⋅⋅ punt ![punt](tpbp-punt.drawio.svg) (which may cause internal events)
           deliver-atomically (mev, top_container (), top_container ())
      ⋅⋅⋅ step ![step](tpbp-step.drawio.svg) (step until no more internal events) 
      	  ⋅⋅⋅⋅ $with-cause (mev)
	     while any-child-ready (top_container ()) {
	       step-ready-children (top_container ())
	     }
	   }
}

⋅ defproc container-reset {
  ⋅⋅reset all children, recursively, then clear own ready-list and input-queue {
    $with-container $self {
    ⋅⋅⋅ reset all children {
        $loop over container.Children -> child {
	  @child.reset
        }
      }
    ⋅⋅⋅clear own ready-list and input-queue {
	@$top-container.ready-list.clear
	@$top-container.inq.clear
      }
    }
  }
}
