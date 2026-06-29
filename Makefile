open:
	open easy-move-resize.xcodeproj
clean:
	xcodebuild -project easy-move-resize.xcodeproj -scheme easy-move-resize-my -configuration Release clean -derivedDataPath ./build

build:
	xcodebuild -project easy-move-resize.xcodeproj -scheme easy-move-resize-my -configuration Release build -derivedDataPath ./build

.PHONY: install build
install: build
	rm -rf ~/Applications/easy-move-resize-my.app
	cp -r ./build/Build/Products/Release/easy-move-resize-my.app ~/Applications/easy-move-resize-my.app