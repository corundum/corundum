// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2022, The Regents of the University of California.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 *    1. Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *
 *    2. Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * The views and conclusions contained in the software and documentation
 * are those of the authors and should not be interpreted as representing
 * official policies, either expressed or implied, of The Regents of the
 * University of California.
 */

#include "mqnic.h"
#include <linux/module.h>

MODULE_DESCRIPTION("mqnic template application driver");
MODULE_AUTHOR("Alex Forencich");
MODULE_LICENSE("Dual BSD/GPL");
MODULE_VERSION("0.1");

struct mqnic_app_template {
	struct device *dev;
	struct mqnic_dev *mdev;
	struct mqnic_adev *adev;

	struct device *nic_dev;

	void __iomem *nic_hw_addr;
	void __iomem *app_hw_addr;
	void __iomem *ram_hw_addr;
};

static int mqnic_app_template_probe(struct auxiliary_device *adev,
		const struct auxiliary_device_id *id)
{
	struct mqnic_app_template *app;
	struct mqnic_dev *mdev = container_of(adev, struct mqnic_adev, adev)->mdev;
	struct device *dev = &adev->dev;

	dev_info(dev, "%s() called", __func__);

	if (!mdev->hw_addr || !mdev->app_hw_addr) {
		dev_err(dev, "Error: required region not present");
		return -EIO;
	}

	app = devm_kzalloc(dev, sizeof(*app), GFP_KERNEL);
	if (!app)
		return -ENOMEM;

	app->dev = dev;
	app->mdev = mdev;
	dev_set_drvdata(&adev->dev, app);

	app->nic_dev = mdev->dev;
	app->nic_hw_addr = mdev->hw_addr;
	app->app_hw_addr = mdev->app_hw_addr;
	app->ram_hw_addr = mdev->ram_hw_addr;

	// Read/write test
	dev_info(dev, "Write to application registers");
	iowrite32(0x11223344, app->app_hw_addr);

	dev_info(dev, "Read from application registers");
	dev_info(dev, "%08x", ioread32(app->app_hw_addr));

	return 0;
}

static void mqnic_app_template_remove(struct auxiliary_device *adev)
{
	struct mqnic_app_template *app = dev_get_drvdata(&adev->dev);
	struct device *dev = app->dev;

	dev_info(dev, "%s() called", __func__);
}

static const struct auxiliary_device_id mqnic_app_template_id_table[] = {
	{ .name = "mqnic.app_12340001" },
	{},
};

MODULE_DEVICE_TABLE(auxiliary, mqnic_app_template_id_table);

static struct auxiliary_driver mqnic_app_template_driver = {
	.name = "mqnic_app_template",
	.probe = mqnic_app_template_probe,
	.remove = mqnic_app_template_remove,
	.id_table = mqnic_app_template_id_table,
};

static int __init mqnic_app_template_init(void)
{
	return auxiliary_driver_register(&mqnic_app_template_driver);
}

static void __exit mqnic_app_template_exit(void)
{
	auxiliary_driver_unregister(&mqnic_app_template_driver);
}

module_init(mqnic_app_template_init);
module_exit(mqnic_app_template_exit);
