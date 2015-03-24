var Node = function(id,type,opts) {
    this.type     = type;
    this.id       = id;
    this.rank     = 0;
    this.parents  = [];
    this.group    = 0;
    this.numsubjects = 0;
    this.subjects = [];
    this.twidth   = SVG.width_of(id);
    this.theight  = SVG.height_of(id);
    //new instance variable for all elements of opts
    for (var i in opts) {
      if(opts.hasOwnProperty(i)) eval("this."+i+" = "+opts[i]+";");
    }

   /* this.bla = function (bla) {
      bla().toString.
    }

    a(function(){ 

  });
  }*/
};
