select_all_resources = function(id, div)
{
  var collection = document.getElementById(div).getElementsByTagName('INPUT');
  for (var x=0; x<collection.length; x++) {
    if (collection[x].type.toUpperCase()=='CHECKBOX')
      collection[x].checked = id.checked;
  }
}
