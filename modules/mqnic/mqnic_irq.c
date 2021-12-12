// SPDX-License-Identifier: BSD-2-Clause-Views
/*
 * Copyright 2021, The Regents of the University of California.
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

static irqreturn_t mqnic_irq_handler(int irqn, void *data)
{
	struct mqnic_irq *irq = data;

	atomic_notifier_call_chain(&irq->nh, 0, NULL);

	return IRQ_HANDLED;
}

int mqnic_irq_init_pcie(struct mqnic_dev *mdev)
{
	struct pci_dev *pdev = mdev->pdev;
	struct device *dev = mdev->dev;
	int ret = 0;
	int k;

	// Allocate MSI IRQs
	mdev->irq_count = pci_alloc_irq_vectors(pdev, 1, MQNIC_MAX_IRQ, PCI_IRQ_MSI);
	if (mdev->irq_count < 0) {
		dev_err(dev, "Failed to allocate IRQs");
		return -ENOMEM;
	}

	// Set up interrupts
	for (k = 0; k < mdev->irq_count; k++) {
		struct mqnic_irq *irq;

		irq = kzalloc(sizeof(*irq), GFP_KERNEL);
		if (!irq) {
			ret = -ENOMEM;
			goto fail;
		}

		ATOMIC_INIT_NOTIFIER_HEAD(&irq->nh);

		ret = pci_request_irq(pdev, k, mqnic_irq_handler, NULL,
				irq, "%s-%d", mdev->name, k);
		if (ret < 0) {
			kfree(irq);
			ret = -ENOMEM;
			dev_err(dev, "Failed to request IRQ %d", k);
			goto fail;
		}

		irq->index = k;
		irq->irqn = pci_irq_vector(pdev, k);
		mdev->irq[k] = irq;
	}

	return 0;
fail:
	mqnic_irq_deinit_pcie(mdev);
	return ret;
}

void mqnic_irq_deinit_pcie(struct mqnic_dev *mdev)
{
	struct pci_dev *pdev = mdev->pdev;
	int k;

	for (k = 0; k < MQNIC_MAX_IRQ; k++) {
		if (mdev->irq[k]) {
			pci_free_irq(pdev, k, mdev->irq[k]);
			kfree(mdev->irq[k]);
			mdev->irq[k] = NULL;
		}
	}

	pci_free_irq_vectors(pdev);
}
