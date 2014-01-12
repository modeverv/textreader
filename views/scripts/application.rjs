/* JS for musicdb */
var AppUtil = {
    isMsIE : /*@cc_on!@*/false,
    debug : function(s,l){
        console.log(s);
    },
    applyToSystem : function(){
        String.prototype.r = String.prototype.replace;
    }
};

/* server */
function init(){
    AppUtil.applyToSystem();
    $("a").click(function(){
                     var link = this.href;
                     window.open( this.href, 'new' );
                     return false;
                 }
                );
}

$(function(){
      init();
  });
