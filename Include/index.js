
	var g_iTop;
	var g_iMaxTop;
	var g_iMinTop;
	var g_dIncrement;
	var g_fLocked = true;
	var g_dDownIncrement;	
	var g_iFramedImage = 1;
	var g_iDVDImage = 1;
	var g_tWav;

	function ondocumentload()
	{
		// Preload images for this page
		new Image().src = "Images/framedBaby2.gif";
		new Image().src = "Images/happybaby.gif";
		new Image().src = "Images/happybaby2.gif";
		
		new Image().src = "Images/Buttons/order2.gif";
		new Image().src = "Images/Buttons/faq2.gif";
		new Image().src = "Images/Buttons/babies2.gif";
		new Image().src = "Images/Buttons/toys2.gif";
		new Image().src = "Images/Buttons/about2.gif";
		new Image().src = "Images/Buttons/contactus2.gif";
		new Image().src = "Images/Buttons/faq2.gif";
		new Image().src = "Images/Buttons/whatis2.gif";
		
		new Image().src = "Images/bbhome2.gif";
		new Image().src = "Images/bbhome3.gif";
		new Image().src = "Images/bbhome4.gif";
		new Image().src = "Images/bbhome5.gif";

		// Preload sounds
		new Image().src = "Sounds/soundclip.wav";
		new Image().src = "Sounds/soundclip1.wav";
		new Image().src = "Sounds/soundclip2.wav";
		new Image().src = "Sounds/soundclip3.wav";
		new Image().src = "Sounds/soundclip4.wav";
		new Image().src = "Sounds/soundclip5.wav";

		g_fLocked = false;
		setTimeout(peekHappyBaby, 5000);
		setInterval(toggleFramedImage, 3000);
		
		
		// Preload images for other pages
		new Image().src = "Images/Buttons/order3.gif";
		new Image().src = "Images/Buttons/faq3.gif";
		new Image().src = "Images/Buttons/babies3.gif";
		new Image().src = "Images/Buttons/toys3.gif";
		new Image().src = "Images/Buttons/about3.gif";
		new Image().src = "Images/Buttons/contactus3.gif";
		new Image().src = "Images/Buttons/webbackground3.gif";
		new Image().src = "Images/Buttons/faq3.gif";
		new Image().src = "Images/Buttons/whatis3.gif";
		
		new Image().src = "Images/Buttons/order4.gif";
		new Image().src = "Images/Buttons/faq4.gif";
		new Image().src = "Images/Buttons/babies4.gif";
		new Image().src = "Images/Buttons/toys4.gif";
		new Image().src = "Images/Buttons/about4.gif";
		new Image().src = "Images/Buttons/contactus4.gif";
		new Image().src = "Images/Buttons/faq4.gif";
		new Image().src = "Images/Buttons/webbackground4.gif";
		new Image().src = "Images/Buttons/whatis4.gif";
	}



	function toggleFramedImage()
	{
		var tSource;

		switch(g_iFramedImage)
		{
			case 0: tSource = "framedBaby.gif"; break;
			case 1: tSource = "framedBaby2.gif"; break;
		}
		document.all.FramedImage.src = "Images/" + tSource;
		g_iFramedImage = (g_iFramedImage + 1) % 2;
	}
	

	

	function setBabyImage()
	{
		var tSource;

		if (Math.random() > 0.5)
		{
			tSource = "happybaby.gif";
		}
		else
		{
			tSource = "happybaby2.gif";
		}

		document.all.HappyBabyImage.src = "Images/" + tSource;
	}

	function peekHappyBaby()
	{
		if (! g_fLocked)
		{
			setBabyImage();
			g_fLocked = true;
			g_iTop = -105;
			g_iMinTop = -145;
			g_iMaxTop = -95;
			g_dIncrement = -5;
			document.all.HappyBabyImage.style.zIndex = 0;
			document.all.HappyBabyImage.style.pixelTop = g_iTop;
			document.all.HappyBabyImage.style.display = "";
			g_iTop += g_dIncrement;
			g_dDownIncrement = 10;
			inchHappyBaby();
		}
		setTimeout(peekHappyBaby, 30000);
	}

	var g_iDontAnnoy = 1.0;
	function raiseHappyBaby(p_oButtonImage,p_tSrc)
	{
		setImageSrc(p_oButtonImage,p_tSrc);

		if (! g_fLocked)
		{
			var dSound = Math.random() * g_iDontAnnoy;
			g_iDontAnnoy = g_iDontAnnoy + 1;
			var tSource;

			if (dSound < 1)
			{
				if (dSound < 0.166)
				{
					tSource = "soundclip.wav";
				}
				else if (dSound < .333)
				{
					tSource = "soundclip1.wav";
				}
				else if (dSound < 0.5)
				{
					tSource = "soundclip2.wav";
				}
				else if (dSound < 0.667)
				{
					tSource = "soundclip3.wav";
				}
				else if (dSound < 0.833)
				{
					tSource = "soundclip4.wav";
				}
				else
				{
					tSource = "soundclip5.wav";
				}

				document.all.soundObject.src = 'Sounds/' + tSource;
			}
			

			g_fLocked = true;
			setBabyImage();
			g_iTop = p_oButtonImage.style.pixelTop + 10;
			g_iMinTop = g_iTop - 80;
			g_iMaxTop = g_iTop;
			g_dIncrement = -15;
			document.all.HappyBabyImage.style.zIndex = p_oButtonImage.style.zIndex - 1;
			document.all.HappyBabyImage.style.pixelTop = g_iTop;
			document.all.HappyBabyImage.style.display = "";
			g_iTop += g_dIncrement;
			g_dDownIncrement = .3;
			inchHappyBaby();
		}		
	}

	function inchHappyBaby()
	{
		if (g_iTop < g_iMaxTop)
		{
			document.all.HappyBabyImage.style.pixelTop = g_iTop;
			if (g_iTop <= g_iMinTop) g_dIncrement = g_dDownIncrement;
			g_iTop += g_dIncrement;
			
			if (g_dIncrement <= 0)
			{
				g_dIncrement *= 0.8;
				if (g_dIncrement > -1) g_dIncrement = -1;
			}
			else 
			{
				g_dIncrement *= 1.2;
			}
			

			setTimeout(inchHappyBaby, 50);
		}
		else
		{
			document.all.HappyBabyImage.style.display = "none";
			g_fLocked = false;
		}
	}

