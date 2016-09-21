var Subject = function(shortid){
  this.shortid    = shortid;
  Subject.counter += 1;
  this.id         = "s"+Subject.counter;
  this.relations  = [];
}

Subject.counter = 0;
