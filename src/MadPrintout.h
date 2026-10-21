///////////////////////////////////////////////////////////////////////////////
// Name:        MadPrintout.h
// Description: Printing functions
// Author:		madedit@gmail.com
// Maintainer:	minggang.li@gmail.com
// Licence: 	GPL
///////////////////////////////////////////////////////////////////////////////

#ifndef _MADPRINTOUT_H_
#define _MADPRINTOUT_H_
#include "MadUtils.h"

class MadPrintout: public wxPrintout
{
    static int s_PrintoutCount;
public:
    explicit MadPrintout(const wxString& title = _("MadEdit-Mod Printout"));
    virtual ~MadPrintout();

    void GetPageInfo(int *minPage, int *maxPage, int *pageFrom, int *pageTo) override;
    bool HasPage(int page) override;
    bool OnPrintPage(int page) override;
    
    void OnPreparePrinting() override;
    
    void CalcPrintInfo(wxPageSetupData *pPageSetupData, double &xScale, double &yScale, wxRect &printRect);
    
    bool m_PrintHeader, m_PrintFooter;
    wxString m_HeaderLeft, m_HeaderCenter, m_HeaderRight;
    wxString m_FooterLeft, m_FooterCenter, m_FooterRight;
    int m_CharHeight, m_HeaderHeight, m_FooterHeight;
};

//extern wxPrintData *g_PrintData;
extern wxPageSetupData* g_PageSetupData;

#endif
