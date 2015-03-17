var Subject = Class.create({
  initialize: function(shortid){
    this.shortid    = shortid;
    this.id         = "s"+Subject.counter;
    Subject.counter += 1;
    this.relations  = [];
  }
});

Subject.counter = 0;
