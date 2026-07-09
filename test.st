$defproc container-handler (self) {
⋅container-handler (self)
  ⋅⋅ handle incoming mevent for a composite part (a "container")
      ⋅⋅⋅ punt incoming mevent down to each child connected to the input
      ⋅⋅⋅ then cause each child to step once and react to the mevent
      ⋅⋅⋅ this might cause the children to generate more mevents internal to the container
      ⋅⋅⋅ so, loop and recursively step all children until internal mevents have died down (quiescence)
      ⋅⋅⋅ i.e. such that all internal reactions to this single incoming mevent have quiesced
      ⋅⋅⋅⋅ ![punt][200](tpbp-punt.drawio.svg)
        $with-container (self) {
           deliver-atomically (mev, @top-container, @top-container)
      ⋅⋅⋅⋅⋅ step until quiescense
      ⋅⋅⋅⋅⋅⋅ ![step][200](tpbp-step.drawio.svg)
           $with-cause (mev) {
             while any-child-ready (@top-container) {
               step-ready-children (@top-container)
             }
           }
        }
}

