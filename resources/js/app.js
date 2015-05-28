/*!
* put application-specific JavaScript code
*/
'use strict';

$('#insert-zone').on("click",function(){
    console.log("insert zone");
    fluxProcessor.dispatch("insert-zone");
});