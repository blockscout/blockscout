# NFTMediaHandler

# NFT Media Handler

`NFTMediaHandler` is an application for resizing and uploading images to R2/S3 storage.

## Configuration

You can modify the application settings in the `config/config.exs` file. Key parameters include:

- `:enabled?` - Enable/disable the application.
- `:remote?` - Use remote mode.
- `:worker?` - Enable worker mode.
- `:worker_concurrency` - Number of concurrent tasks.
- `:worker_batch_size` - Batch size for tasks.
- `:worker_spawn_tasks_timeout` - Timeout between task spawns.
- `:tmp_dir` - Temporary directory for storing files.

## Project Structure
- `lib/nft_media_handler/application.ex` - Main application module.
- `lib/nft_media_handler.ex` - Main module for processing and uploading media.
- `lib/nft_media_handler/dispatcher.ex` - Module for managing tasks.
- `lib/nft_media_handler/dispatcher_interface.ex` - Interface for interacting with the dispatcher.
- `lib/nft_media_handler/image/resizer.ex` - Module for resizing images.
- `lib/nft_media_handler/media/fetcher.ex `- Module for fetching media from various sources.
- `lib/nft_media_handler/r2/uploader.ex` - Module for uploading images to R2/S3.

## Usage Examples

### Resizing an Image
To resize an image, use the NFTMediaHandler.Image.Resizer.resize/3 function:
```
image = Vix.Vips.Image.new_from_file("path/to/image.jpg")
resized_images = NFTMediaHandler.Image.Resizer.resize(image, "http://example.com/image.jpg", ".jpg")
```

### Uploading an Image
To upload an image, use the NFTMediaHandler.R2.Uploader.upload_image/3 function:
```
{:ok, result} = NFTMediaHandler.R2.Uploader.upload_image(image_binary, "image.jpg", "folder")
```

### Fetching Media
To fetch media, use the NFTMediaHandler.Media.Fetcher.fetch_media/2 function:
```
{:ok, media_type, body} = NFTMediaHandler.Media.Fetcher.fetch_media("http://example.com/media.jpg", [])
```
