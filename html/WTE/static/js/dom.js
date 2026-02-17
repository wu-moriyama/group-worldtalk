var dom = new Object();
dom.core = new Object();
dom.event = new Object();

/* ----------------------------------------------------------------------------
* Core
* -------------------------------------------------------------------------- */

dom.core.getElementsByClassName = function(element, classNames) {
	if(element.getElementsByClassName) {
		return element.getElementsByClassName(classNames);
	}
	var tokens = dom.core._split_a_string_on_spaces(classNames);
	var tn = tokens.length;
	var nodes = element.all ? element.all : element.getElementsByTagName("*");
	var n = nodes.length;
	var array = new Array();
	if( tn > 0 ) {
		if( document.evaluate ) {
			var contains = new Array();
			for(var i=0; i<tn; i++) {
				contains.push('contains(concat(" ",@class," "), " '+ tokens[i] + '")');
			}
			var xpathExpression = "/descendant::*[" + contains.join(" and ") + "]";
			var iterator = document.evaluate(xpathExpression, element, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);
			var inum = iterator.snapshotLength;
			for( var i=0; i<inum; i++ ) {
				var elm = iterator.snapshotItem(i);
				if( elm != element ) {
					array.push(iterator.snapshotItem(i));
				}
			}
		} else {
			for(var i=0; i<n; i++) {
				var elm = nodes.item(i);
				if( elm.className == "" ) { continue; }
				var class_list = dom.core._split_a_string_on_spaces(elm.className);
				var class_name = class_list.join(" ");
				var f = true;
				for(var j=0; j<tokens.length; j++) {
					var re = new RegExp('(^|\\s)' + tokens[j] + '(\\s|$)')
					if( ! re.test(class_name) ) {
						f = false;
						break;
					}
				}
				if(f == true) {
					array.push(elm);
				}
			}
		}
	}
	/* add item(index) method to the array as if it behave as a NodeList interface. */
	array.item = function(index) {
		if(array[index]) {
			return array[index];
		} else {
			return null;
		}
	};
	//
	return array;
};

/* split a string on spaces */
dom.core._split_a_string_on_spaces = function(string) {
	string = string.replace(/^[\t\s]+/, "");
	string = string.replace(/[\t\s]+$/, "");
	var tokens = string.split(/[\t\s]+/);
	return tokens;
};

/* ----------------------------------------------------------------------------
* Event
* -------------------------------------------------------------------------- */

dom.event.addEventListener = function(elm, type, func, useCapture) {
  if(! elm) { return false; }
  if(! useCapture) {
    useCapture = false;
  }
  if(elm.addEventListener) {
    elm.addEventListener(type, func, false);
  } else if(elm.attachEvent) {
    elm.attachEvent('on'+type, func);
  } else {
    return false;
  }
  return true;
};

dom.event.removeEventListener = function(elm, type, func, useCapture) {
  if(! elm) { return false; }
  if(! useCapture) {
    useCapture = false;
  }
  if(elm.removeEventListener) {
    elm.removeEventListener(type, func, false);
  } else if(elm.detachEvent) {
    elm.detachEvent('on'+type, func);
  } else {
    return false;
  }
  return true;
};

dom.event.target = function(evt) {
  if(evt && evt.target) {
    if(evt.target.nodeType == 3) {
      return evt.target.parentNode;
    } else {
      return evt.target;
    }
  } else if(window.event && window.event.srcElement) {
    return window.event.srcElement;
  } else {
    return null;
  }
};

dom.event.preventDefault = function(evt) {
  if(evt && evt.preventDefault) {
    evt.preventDefault();
    evt.currentTarget['on'+evt.type] = function() {return false;};
  } else if(window.event) {
    window.event.returnValue = false;
  }
};

dom.event.stopPropagation = function(evt) {
  if(evt && evt.stopPropagation) {
    evt.stopPropagation();
  } else if(window.event) {
    window.event.cancelBubble = true;
  }
};

dom.event.dispatchEvent = function(elm, evttype) {
  if(elm && elm.dispatchEvent) {
    var evt = document.createEvent('MouseEvents');
    evt.initEvent(evttype, true, true);
    elm.dispatchEvent(evt);
  } else if(window.event) {
    var evt = document.createEventObject();
    evt.button = 1;
    elm.fireEvent('on'+evttype, evt);
  }
}
