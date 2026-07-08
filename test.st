defproc container-handler {
  .handle incoming mevent for a composite part (a "container")
    ..%with-container %self
      ...punt mevent to children
         {
	   # tos is a mev
	   <mev
           >(mev %top-container %top-container) @deliver-atomically
      ...step children recursively until quiescence
      	  ....%with-cause mev {
	     %while >%top-container @any-child-ready {
	       >%top-container @step-ready-children
	     }
	   }
}



⋅ leaf runtime object ![ėleaf][300](tinypbp-leaf-eh.drawio.svg)
defobj ėleaf {
  &inq
  &outq
  high-priority
  λhandler
  λreset
}



defproc container-handler (self) {
  ⋅ handle incoming mevent for a composite part (a "container")
    ⋅⋅ $with-container (self)
      ⋅⋅⋅ punt ![punt][200](tpbp-punt.drawio.svg) (which may cause internal events)
           deliver-atomically (mev, top_container (), top_container ())
      ⋅⋅⋅ step ![step][200](tpbp-step.drawio.svg) (step until no more internal events) 
      	  ⋅⋅⋅⋅ $with-cause (mev)
	     while any-child-ready (top_container ()) {
	       step-ready-children (top_container ())
	     }
	   }
}




⋅ defproc container-handler (mev) {
  ⋅⋅ handle incoming mevent for a composite part (a "container")
    ⋅⋅⋅ $with-container $self {
      ⋅⋅⋅⋅ punt ![punt][200](tpbp-punt.drawio.svg) (which may cause internal events)
           @deliver-atomically (mev @top_container @top_container)
      ⋅⋅⋅⋅ step ![step][200](tpbp-step.drawio.svg) (step until no more internal events) 
      	  ⋅⋅⋅⋅⋅ $with-cause (mev)
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
