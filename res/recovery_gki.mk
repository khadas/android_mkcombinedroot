# Rockchip 2022 makefile
# Generate from vendor/rockchip/gki/modular_kernel/configs/recovery_modules.load
BOARD_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_GKI_DIR)/res/recovery_modules.load))

ifndef BOARD_RECOVERY_KERNEL_MODULES_LOAD
$(error recovery_modules.load not found or empty)
endif

BOARD_RECOVERY_KERNEL_MODULES := $(addprefix $(KERNEL_DRIVERS_PATH)/, $(notdir $(BOARD_RECOVERY_KERNEL_MODULES_LOAD)))
