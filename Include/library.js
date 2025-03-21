function setImageSrc(p_oImage,p_tSrc)
{
	p_oImage.src='Images/Buttons/' + p_tSrc;
}



function mailThisUrl(address)
{
	var email_subject = 'Check out this web page I found...';
	var email_body = 'This page has great activities for preschoolers that I thought you might like.  Check it out when you get a chance.';
	var page_url = window.self.location.href.split( '?' )[0];
	page_url = page_url + '?source=email_friend';
	window.location = 'mailto:' + address + '?subject=' +
		escape( email_subject ) + '&body=' +
		escape( document.title + ': ' + email_body + ': ' + page_url );
}
