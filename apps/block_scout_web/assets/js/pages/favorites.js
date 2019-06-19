import $ from 'jquery'

var favoritesQuantity = 0,
	favoritesContainer = $(".js-favorites-tab"),
	favoritesNetworksUrls = [];

$(document).on("change", ".network-selector-item-favorite input[type='checkbox']", function () {
	
	var networkUrl = $(this).attr("data-url"),
		thisStatus = $(this).is(":checked"),
		parent = $(".network-selector-item[data-url='" + networkUrl +"'").clone(),
		workWith = $(".network-selector-item[data-url='" + networkUrl +"'");
	
	// Add new checkbox status to same network in another tabs
	$(".network-selector-item-favorite input[data-url='" + networkUrl +"']").prop("checked", thisStatus);
	
	// Push or remove favorite networks to array
	var found = $.inArray(networkUrl, favoritesNetworksUrls);
	if (found < 0 && thisStatus == true) {
		favoritesNetworksUrls.push(networkUrl);
	} else {
		var index = favoritesNetworksUrls.indexOf(networkUrl);
		if(index!=-1){
			favoritesNetworksUrls.splice(index, 1);
		}
	}
	console.log(favoritesNetworksUrls);
	// Append or remove item from 'favorites' tab
	
	if (thisStatus == true) {
		favoritesContainer.append(parent[0]);
		$(".js-favorites-tab .network-selector-tab-content-empty").hide();
	} else {
		var willRemoved = favoritesContainer.find(workWith);
		willRemoved.remove();
		if (favoritesNetworksUrls.length == 0) {
			$(".js-favorites-tab .network-selector-tab-content-empty").show();
		}
	}

});