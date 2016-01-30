DocUtils=require('./docUtils')
DocxQrCode=require('./docxQrCode')
PNG=require('png-js')
JSZip=require('jszip')

module.exports= class ImgReplacer
	constructor: (@xmlTemplater,@imgManager)->
		@imgMatches=[]
		@xmlTemplater.numQrCode=0
		this
	findImages:() ->
		@imgMatches= DocUtils.pregMatchAll /<w:drawing[^>]*>.*?<a:blip.r:embed.*?<\/w:drawing>/g, @xmlTemplater.content
		this
	replaceImages: ()->
		@qr=[]
		@xmlTemplater.numQrCode+=@imgMatches.length
		@replaceImage(match,u) for match,u in @imgMatches
		this
	imageSetter:(docxqrCode) =>
		if docxqrCode.callbacked==true then return
		docxqrCode.callbacked=true
		docxqrCode.xmlTemplater.numQrCode--
		@imgManager.setImage("word/media/#{docxqrCode.imgName}",docxqrCode.data,{binary:true})
		@popQrQueue(@imgManager.fileName+'-'+docxqrCode.num,false)
	replaceImage:(match,u)->
		num=parseInt(Math.random()*10000)
		try
			baseDocument = """<?xml version="1.0" ?>
			<w:document
			mc:Ignorable="w14 wp14"
			xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
			xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
			xmlns:o="urn:schemas-microsoft-com:office:office"
			xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
			xmlns:v="urn:schemas-microsoft-com:vml"
			xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
			xmlns:w10="urn:schemas-microsoft-com:office:word"
			xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
			xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
			xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
			xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
			xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
			xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
			xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
			xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">#{match[0]}</w:document>
			"""
			f=(_i,type)->
				if _i=='fatalError'
					throw "fatalError"
			xmlImg= DocUtils.Str2xml baseDocument,f
		catch e
			return
		tagrId= xmlImg.getElementsByTagName("a:blip")[0]
		if tagrId==undefined then throw new Error('tagRiD undefined !')
		rId = tagrId.getAttribute('r:embed')
		oldFile= @imgManager.getImageByRid(rId)
		tag= xmlImg.getElementsByTagName("wp:docPr")[0]
		if tag==undefined then throw new Error('tag undefined')
		if tag.getAttribute("name").substr(0,6)=="Copie_" then return #if image is already a replacement then do nothing
		imgName= @imgManager.getImageName()
		@pushQrQueue(@imgManager.fileName+'-'+num,true)
		newId= @imgManager.addImageRels(imgName,"")
		@xmlTemplater.imageId++
		@imgManager.setImage(@imgManager.getFullPath(imgName),oldFile.data,{binary:true})
		tag.setAttribute('name',"#{imgName}")
		tagrId.setAttribute('r:embed',"rId#{newId}")
		imageTag=xmlImg.getElementsByTagName('w:drawing')[0]
		if imageTag==undefined then throw new Error('imageTag undefined')
		replacement= DocUtils.xml2Str imageTag
		@xmlTemplater.content= @xmlTemplater.content.replace(match[0], replacement)
		mockedQrCode={xmlTemplater:@xmlTemplater,imgName:imgName,data:oldFile.asBinary(),num:num}
		if /\.png$/.test(oldFile.name)
			do (imgName) =>
				base64= JSZip.base64.encode oldFile.asBinary()
				binaryData = new Buffer(base64, 'base64')
				png= new PNG(binaryData)
				finished= (a) =>
					png.decoded= a
					try
						@qr[u]= new DocxQrCode(png,@xmlTemplater,imgName,num,@getDataFromString)
						@qr[u].decode(@imageSetter)
					catch e
						console.error e
						console.error e.stack
						@imageSetter(mockedQrCode)
				dat= png.decode(finished)
		else
			@imageSetter(mockedQrCode)
