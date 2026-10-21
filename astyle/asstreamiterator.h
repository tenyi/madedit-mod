/*
 * This file is part of the Code::Blocks IDE and licensed under the GNU General Public License, version 3
 * http://www.gnu.org/licenses/gpl-3.0.html
 */

#ifndef ASSTREAMITERATOR_H
#define ASSTREAMITERATOR_H

#include <iostream>

#include <wx/string.h>

#include "astyle/astyle.h"

class MadEdit;
class ASStreamIterator : public astyle::ASSourceIterator
{
    public:
        ASStreamIterator(MadEdit* cbe, const wxChar* in);
        virtual ~ASStreamIterator();

        bool hasMoreLines() const override;
        int  getStreamLength() const override;
        std::streamoff getPeekStart() const override { return 0; }
        std::string nextLine(bool emptyLineWasDeleted = false) override;
        std::string peekNextLine() override;
        void peekReset() override;
        std::streamoff tellg() override;

        bool FoundBookmark() const   { return m_FoundBookmark;    }
        void ClearFoundBookmark()    { m_FoundBookmark = false;   }
        bool FoundBreakpoint() const { return m_FoundBreakpoint;  }
        void ClearFoundBreakpoint()  { m_FoundBreakpoint = false; }

    protected:
        inline bool IsEOL(wxChar ch) { return (ch == _T('\r') || ch == _T('\n')); }

        MadEdit*           m_Ed;
        const wxChar*       m_CharPtr;
        const wxChar*       m_SavedCharPtr;
        int                 m_CurChar;
        int                 m_SavedCurChar;
        int                 m_CurLine;
        bool                m_FoundBookmark;
        bool                m_FoundBreakpoint;

    private:
        std::string readLine();
};

#endif // ASSTREAMITERATOR_H
